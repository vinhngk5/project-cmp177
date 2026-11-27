/// Điều khiển một phòng chat (thuần Dart, không phụ thuộc Flutter).
///
/// Một [ChatController] = một user + một hội thoại. Đổi tài khoản = dựng
/// controller mới (và gọi [ChatController.logout] trên controller cũ).
/// Tham chiếu: FR-CHAT-06..09, AC-CHAT-05..09, AC-ERR-04..06, E-02, E-19, E-20.
library;

import 'dart:async';

import 'api_error.dart';
import 'chat_utils.dart';
import 'constants.dart';
import 'enums.dart';
import 'models.dart';
import 'repositories.dart';
import 'validators.dart';

/// Mã lỗi server báo hội thoại không còn gửi được (SRS 12.3: hội thoại đóng,
/// user bị ban, product không còn hợp lệ). Gặp các mã này thì phòng chuyển
/// read-only kể cả khi event ghi `retryable = true`.
const Set<String> kChatReadOnlyErrorCodes = {
  'CONVERSATION_READ_ONLY',
  'CONVERSATION_CLOSED',
  'ACCOUNT_BANNED',
  'PRODUCT_NOT_AVAILABLE',
  'PRODUCT_NOT_FOUND',
};

enum ChatConnectionStatus {
  /// Chưa gọi `start()`.
  idle,
  connecting,
  connected,

  /// Mất kết nối, đang chờ / đang thử nối lại (E-19).
  reconnecting,

  /// Đã đóng, hoặc bỏ cuộc sau `maxReconnectAttempts`, hoặc không có quyền.
  disconnected,
}

const Object _unset = Object();

class ChatState {
  const ChatState({
    this.messages = const <Message>[],
    this.connection = ChatConnectionStatus.idle,
    this.readOnly = false,
    this.loadingHistory = false,
    this.hasMoreHistory = true,
    this.nextCursor,
    this.error,
  });

  /// Đã merge (REST + WebSocket + tin pending), sắp xếp theo thời gian tăng dần.
  final List<Message> messages;
  final ChatConnectionStatus connection;

  /// Phòng chỉ đọc: không gửi được nữa (AC-CHAT-09).
  final bool readOnly;
  final bool loadingHistory;
  final bool hasMoreHistory;

  /// Cursor để tải trang lịch sử cũ hơn (`before`).
  final String? nextCursor;

  /// Thông báo lỗi tiếng Việt gần nhất (null nếu không có).
  final String? error;

  /// Danh sách để vẽ UI, đã chèn phân cách ngày (FR-CHAT-08).
  List<ChatItem> get items => groupByDay(messages);

  ChatState copyWith({
    List<Message>? messages,
    ChatConnectionStatus? connection,
    bool? readOnly,
    bool? loadingHistory,
    bool? hasMoreHistory,
    Object? nextCursor = _unset,
    Object? error = _unset,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        connection: connection ?? this.connection,
        readOnly: readOnly ?? this.readOnly,
        loadingHistory: loadingHistory ?? this.loadingHistory,
        hasMoreHistory: hasMoreHistory ?? this.hasMoreHistory,
        nextCursor:
            identical(nextCursor, _unset) ? this.nextCursor : nextCursor as String?,
        error: identical(error, _unset) ? this.error : error as String?,
      );
}

DateTime _utcNow() => DateTime.now().toUtc();

Future<void> _realDelay(Duration d) => Future<void>.delayed(d);

Duration _defaultBackoff(int attempt) => reconnectDelay(attempt);

int _idCounter = 0;

/// Id mặc định khi app không inject UUID: đủ duy nhất trên một thiết bị.
/// App thật nên truyền `newClientMessageId` sinh UUID v4.
String _defaultClientMessageId() {
  _idCounter++;
  final micros = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  return 'c$micros-${_idCounter.toRadixString(36)}';
}

String _pendingId(String clientMessageId) => 'pending-$clientMessageId';

String? _oldestId(List<Message> items) {
  if (items.isEmpty) return null;
  var oldest = items.first;
  for (final m in items) {
    if (m.createdAt.isBefore(oldest.createdAt)) oldest = m;
  }
  return oldest.id;
}

class ChatController {
  ChatController({
    required this.conversationId,
    required this.userId,
    required this.repository,
    required this.socket,
    Outbox? outbox,
    DateTime Function()? clock,
    String Function()? newClientMessageId,
    Future<void> Function(Duration)? delay,
    Duration Function(int attempt)? backoff,
    this.maxReconnectAttempts = 10,
    this.resyncMaxPages = 5,
    bool initialReadOnly = false,
  })  : outbox = outbox ?? Outbox(),
        _clock = clock ?? _utcNow,
        _newClientMessageId = newClientMessageId ?? _defaultClientMessageId,
        _delay = delay ?? _realDelay,
        _backoff = backoff ?? _defaultBackoff,
        _state = ChatState(readOnly: initialReadOnly);

  final String conversationId;
  final String userId;
  final ChatRepository repository;
  final ChatSocket socket;

  /// Outbox có thể dùng chung giữa nhiều controller (nhiều phòng, nhiều user);
  /// mọi thao tác đều theo `userId` nên không gửi nhầm sang tài khoản khác.
  final Outbox outbox;

  /// Số lần nối lại tối đa liên tiếp trước khi bỏ cuộc (E-19: backoff có giới hạn).
  final int maxReconnectAttempts;

  /// Số trang REST tối đa tải lại sau reconnect để lấp khoảng trống.
  final int resyncMaxPages;

  final DateTime Function() _clock;
  final String Function() _newClientMessageId;
  final Future<void> Function(Duration) _delay;
  final Duration Function(int attempt) _backoff;

  final StreamController<ChatState> _states =
      StreamController<ChatState>.broadcast();
  ChatState _state;
  StreamSubscription<ChatSocketEvent>? _eventsSub;

  bool _started = false;
  bool _closed = false;

  // Vòng reconnect.
  bool _loopRunning = false;
  bool _reconnectRequested = false;
  int _reconnectAttempt = 0;

  // Xả outbox.
  bool _flushing = false;
  bool _flushAgain = false;

  // Tin đã gửi trên kết nối hiện tại và đang chờ ACK (không gửi lại trong cùng
  // một kết nối; xóa khi mất kết nối để gửi lại với cùng clientMessageId).
  final Set<String> _sentOnConnection = <String>{};

  /// Luồng state. Chỉ phát thay đổi từ lúc subscribe; đọc [state] để lấy giá trị
  /// hiện tại trước khi lắng nghe.
  Stream<ChatState> get states => _states.stream;

  ChatState get state => _state;

  // ---------------------------------------------------------------------
  // Vòng đời
  // ---------------------------------------------------------------------

  /// Nạp tin outbox cũ của user vào phòng, kết nối socket, tải lịch sử, đánh
  /// dấu đã đọc. Không ném lỗi: lỗi được phản ánh trong [state].
  Future<void> start() async {
    if (_started || _closed) return;
    _started = true;
    _eventsSub = socket.events.listen(
      _onEvent,
      onError: (Object _) => _handleConnectionLost(null),
    );
    _restoreFromOutbox();
    await _connectInitial();
    if (_closed) return;
    await loadHistory();
    if (_closed) return;
    await markRead();
  }

  /// Đóng controller nhưng giữ outbox (ví dụ rời màn hình chat).
  Future<void> dispose() => _shutdown(wipeState: false, clearOutbox: false);

  /// Đăng xuất / đổi tài khoản (AC-CHAT-08, AC-ERR-06, E-20): dừng reconnect,
  /// đóng socket, xóa tin trong bộ nhớ. Mặc định xóa luôn outbox của user này;
  /// truyền `clearOutbox: false` nếu chính sách là giữ local. Dù chọn gì, outbox
  /// của user này cũng không bao giờ được gửi bằng user khác.
  Future<void> logout({bool clearOutbox = true}) =>
      _shutdown(wipeState: true, clearOutbox: clearOutbox);

  Future<void> _shutdown({
    required bool wipeState,
    required bool clearOutbox,
  }) async {
    if (_closed) return;
    _closed = true;
    _reconnectRequested = false;
    _sentOnConnection.clear();
    final sub = _eventsSub;
    _eventsSub = null;
    await sub?.cancel();
    if (clearOutbox) outbox.clearUser(userId);
    try {
      await socket.close();
    } catch (_) {
      // Đóng thất bại không ảnh hưởng việc dọn dẹp.
    }
    final next = wipeState
        ? const ChatState(
            connection: ChatConnectionStatus.disconnected,
            hasMoreHistory: false,
          )
        : _state.copyWith(connection: ChatConnectionStatus.disconnected);
    _emit(next, force: true);
    await _states.close();
  }

  void _emit(ChatState next, {bool force = false}) {
    if (_closed && !force) return;
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }

  void _setConnection(ChatConnectionStatus c) {
    if (_state.connection == c) return;
    _emit(_state.copyWith(connection: c));
  }

  // ---------------------------------------------------------------------
  // Lịch sử (REST, cursor)
  // ---------------------------------------------------------------------

  /// Tải trang lịch sử tiếp theo (lần đầu: trang mới nhất; các lần sau: cũ hơn
  /// theo cursor). Không làm gì nếu đang tải hoặc đã hết.
  Future<void> loadHistory() async {
    if (_closed || _state.loadingHistory || !_state.hasMoreHistory) return;
    _emit(_state.copyWith(loadingHistory: true, error: null));
    try {
      final page = await repository.fetchMessages(
        conversationId,
        before: _state.nextCursor,
        limit: kHistoryDefaultLimit,
      );
      if (_closed) return;
      _reconcileOutbox(page.items);
      _emit(_state.copyWith(
        messages: mergeMessages(_state.messages, page.items),
        loadingHistory: false,
        hasMoreHistory: page.hasMore,
        nextCursor:
            page.hasMore ? (page.nextCursor ?? _oldestId(page.items)) : null,
      ));
    } catch (e) {
      if (_closed) return;
      _emit(_state.copyWith(
        loadingHistory: false,
        error: errorMessageOf(e),
      ));
    }
  }

  /// Đánh dấu đã đọc (best-effort: lỗi mạng không làm hỏng phòng chat).
  Future<void> markRead() async {
    try {
      await repository.markRead(conversationId);
    } catch (_) {
      // Sẽ được đánh dấu lại lần mở phòng sau.
    }
  }

  // ---------------------------------------------------------------------
  // Gửi tin
  // ---------------------------------------------------------------------

  /// Gửi tin văn bản. Trả về thông báo lỗi tiếng Việt nếu bị từ chối ngay
  /// (rỗng, quá dài, phòng read-only), ngược lại trả null: tin đã vào state ở
  /// trạng thái pending và nằm trong outbox, sẽ được gửi ngay nếu đang kết nối,
  /// hoặc gửi sau khi nối lại (E-02).
  Future<String?> send(String text) async {
    if (_closed) return kMsgGeneric;
    if (_state.readOnly) return kMsgChatReadOnly;
    final invalid = validateMessageText(text);
    if (invalid != null) return invalid;

    final body = text.trim();
    final cid = _newClientMessageId();
    final now = _clock();
    outbox.add(
      userId,
      OutboxEntry(
        clientMessageId: cid,
        conversationId: conversationId,
        text: body,
        createdAt: now,
      ),
    );
    final pending = Message(
      id: _pendingId(cid),
      conversationId: conversationId,
      senderId: userId,
      type: MessageType.text,
      text: body,
      createdAt: now,
      clientMessageId: cid,
      sendStatus: SendStatus.pending,
    );
    _emit(_state.copyWith(
      messages: mergeMessages(_state.messages, [pending]),
      error: null,
    ));
    if (_state.connection == ChatConnectionStatus.connected) {
      await _flushOutbox();
    }
    return null;
  }

  /// Gửi lại các tin đã `failed` (người dùng bấm "thử lại"). Không làm gì nếu
  /// phòng read-only.
  Future<void> retryFailed() async {
    if (_closed || _state.readOnly) return;
    var any = false;
    for (final e in outbox.entriesFor(userId)) {
      if (e.conversationId == conversationId && e.status == SendStatus.failed) {
        e.status = SendStatus.pending;
        e.attempts = 0;
        _sentOnConnection.remove(e.clientMessageId);
        any = true;
      }
    }
    if (!any) return;
    _emit(_state.copyWith(messages: [
      for (final m in _state.messages)
        m.sendStatus == SendStatus.failed
            ? m.copyWith(sendStatus: SendStatus.pending)
            : m,
    ]));
    if (_state.connection == ChatConnectionStatus.connected) {
      await _flushOutbox();
    } else if (_state.connection == ChatConnectionStatus.disconnected) {
      reconnect();
    }
  }

  /// Nối lại thủ công (sau khi đã bỏ cuộc vì hết số lần thử).
  void reconnect() {
    if (_closed || _state.readOnly) return;
    if (_state.connection == ChatConnectionStatus.connected) return;
    _reconnectAttempt = 0;
    _scheduleReconnect();
  }

  void _restoreFromOutbox() {
    final restored = <Message>[];
    for (final e in outbox.entriesFor(userId)) {
      if (e.conversationId != conversationId) continue;
      restored.add(Message(
        id: _pendingId(e.clientMessageId),
        conversationId: conversationId,
        senderId: userId,
        type: MessageType.text,
        text: e.text,
        createdAt: e.createdAt,
        clientMessageId: e.clientMessageId,
        sendStatus: e.status,
      ));
    }
    if (restored.isEmpty) return;
    _emit(_state.copyWith(messages: mergeMessages(_state.messages, restored)));
  }

  /// Gửi các entry còn pending của chính user này trong phòng này.
  Future<void> _flushOutbox() async {
    if (_flushing) {
      _flushAgain = true;
      return;
    }
    _flushing = true;
    try {
      do {
        _flushAgain = false;
        for (final entry in outbox.retryable(userId)) {
          if (_closed ||
              _state.readOnly ||
              _state.connection != ChatConnectionStatus.connected) {
            break;
          }
          if (entry.conversationId != conversationId) continue;
          if (entry.status != SendStatus.pending) continue;
          if (_sentOnConnection.contains(entry.clientMessageId)) continue;
          await _sendEntry(entry);
        }
      } while (_flushAgain && !_closed);
    } finally {
      _flushing = false;
    }
  }

  Future<void> _sendEntry(OutboxEntry entry) async {
    final cid = entry.clientMessageId;
    _sentOnConnection.add(cid);
    var delivered = true;
    try {
      await socket.send(conversationId, cid, entry.text);
    } catch (_) {
      delivered = false;
    }
    if (_closed) return;
    outbox.markAttempt(userId, cid);
    if (entry.status == SendStatus.failed) {
      // Hết số lần thử: không retry vô hạn (AC-ERR-05).
      _sentOnConnection.remove(cid);
      _markFailedInState(cid);
    }
    if (!delivered) {
      _sentOnConnection.remove(cid);
      _handleConnectionLost(null);
    }
  }

  void _markFailedInState(String clientMessageId) {
    _emit(_state.copyWith(messages: [
      for (final m in _state.messages)
        m.clientMessageId == clientMessageId &&
                m.sendStatus == SendStatus.pending
            ? m.copyWith(sendStatus: SendStatus.failed)
            : m,
    ]));
  }

  /// Nếu server đã có tin mang `client_message_id` trong outbox (ACK bị mất)
  /// thì bỏ khỏi outbox để không gửi lại (SRS flowchart "Backend already has id").
  void _reconcileOutbox(List<Message> incoming) {
    for (final m in incoming) {
      final cid = m.clientMessageId;
      if (cid != null && m.senderId == userId) {
        outbox.markSent(userId, cid);
        _sentOnConnection.remove(cid);
      }
    }
  }

  // ---------------------------------------------------------------------
  // Sự kiện socket
  // ---------------------------------------------------------------------

  void _onEvent(ChatSocketEvent event) {
    if (_closed) return;
    switch (event) {
      case MessageAck ack:
        _onAck(ack);
      case MessageNew created:
        _onNew(created);
      case SocketError err:
        _onSocketError(err);
      case Disconnected gone:
        _handleConnectionLost(gone.closeCode);
    }
  }

  void _onAck(MessageAck ack) {
    final cid = ack.clientMessageId;
    outbox.markSent(userId, cid);
    _sentOnConnection.remove(cid);
    final idx = _state.messages.indexWhere(
      (m) => m.clientMessageId == cid && m.sendStatus != SendStatus.sent,
    );
    if (idx < 0) return;
    final sent = _state.messages[idx].copyWith(
      id: ack.messageId,
      sendStatus: SendStatus.sent,
      createdAt: ack.createdAt,
    );
    _emit(_state.copyWith(
      messages: mergeMessages(_state.messages, [sent]),
      error: null,
    ));
  }

  void _onNew(MessageNew event) {
    if (event.conversationId != conversationId) return;
    _emit(_state.copyWith(
      messages: mergeMessages(_state.messages, [event.message]),
    ));
  }

  void _onSocketError(SocketError err) {
    final target = err.conversationId;
    if (target != null && target != conversationId) return;
    if (!err.retryable || kChatReadOnlyErrorCodes.contains(err.code)) {
      _enterReadOnly();
      return;
    }
    _emit(_state.copyWith(error: messageForError(code: err.code)));
  }

  /// Phòng không gửi được nữa: tin pending -> failed, không retry (AC-CHAT-09).
  void _enterReadOnly() {
    outbox.failConversation(userId, conversationId);
    _sentOnConnection.clear();
    _emit(_state.copyWith(
      messages: [
        for (final m in _state.messages)
          m.sendStatus == SendStatus.pending
              ? m.copyWith(sendStatus: SendStatus.failed)
              : m,
      ],
      readOnly: true,
      error: kMsgChatReadOnly,
    ));
  }

  /// Mất kết nối (event Disconnected, lỗi stream hoặc gửi thất bại).
  /// 4403: không có quyền -> read-only, không nối lại. 4401 và các mã khác:
  /// nối lại có backoff (`socket.connect()` chịu trách nhiệm lấy token mới).
  void _handleConnectionLost(int? closeCode) {
    if (_closed) return;
    _sentOnConnection.clear();
    if (closeCode == kWsCloseForbidden) _enterReadOnly();
    if (_state.readOnly) {
      _reconnectRequested = false;
      _setConnection(ChatConnectionStatus.disconnected);
      return;
    }
    _scheduleReconnect();
  }

  // ---------------------------------------------------------------------
  // Kết nối / reconnect
  // ---------------------------------------------------------------------

  Future<void> _connectInitial() async {
    _setConnection(ChatConnectionStatus.connecting);
    try {
      await socket.connect();
    } catch (_) {
      _scheduleReconnect();
      return;
    }
    if (_closed) return;
    _reconnectAttempt = 0;
    _setConnection(ChatConnectionStatus.connected);
    await _flushOutbox();
  }

  void _scheduleReconnect() {
    if (_closed) return;
    _setConnection(ChatConnectionStatus.reconnecting);
    _reconnectRequested = true;
    if (_loopRunning) return;
    _loopRunning = true;
    unawaited(_reconnectLoop());
  }

  Future<void> _reconnectLoop() async {
    try {
      while (_reconnectRequested && !_closed) {
        if (_reconnectAttempt >= maxReconnectAttempts) {
          _reconnectRequested = false;
          _reconnectAttempt = 0;
          _setConnection(ChatConnectionStatus.disconnected);
          break;
        }
        final wait = _backoff(_reconnectAttempt);
        _reconnectAttempt++;
        await _delay(wait);
        if (_closed) break;
        // Đặt cờ về false TRƯỚC khi nối: nếu có Disconnected trong lúc/ngay sau
        // khi nối, cờ sẽ được bật lại và vòng lặp chạy tiếp.
        _reconnectRequested = false;
        try {
          await socket.connect();
        } catch (_) {
          _reconnectRequested = true;
          continue;
        }
        if (_closed) break;
        if (_reconnectRequested) continue;
        _reconnectAttempt = 0;
        _setConnection(ChatConnectionStatus.connected);
        await _afterReconnect();
      }
    } finally {
      _loopRunning = false;
    }
  }

  /// Sau reconnect: gửi lại outbox (cùng clientMessageId) rồi đồng bộ lịch sử
  /// qua REST (AC-CHAT-06, AC-CHAT-07, AC-ERR-04).
  Future<void> _afterReconnect() async {
    await _flushOutbox();
    if (_closed) return;
    await _resyncHistory();
  }

  /// Tải trang mới nhất; nếu chưa chạm tới tin đã biết thì tải tiếp trang cũ
  /// hơn (tối đa [resyncMaxPages]) để lấp khoảng trống lúc offline.
  Future<void> _resyncHistory() async {
    try {
      final hadSent =
          _state.messages.any((m) => m.sendStatus == SendStatus.sent);
      String? before;
      for (var i = 0; i < resyncMaxPages; i++) {
        final page = await repository.fetchMessages(
          conversationId,
          before: before,
          limit: kHistoryDefaultLimit,
        );
        if (_closed) return;
        final known = <String>{
          for (final m in _state.messages)
            if (m.sendStatus == SendStatus.sent) m.id,
        };
        final overlap = page.items.any((m) => known.contains(m.id));
        _reconcileOutbox(page.items);
        final merged = mergeMessages(_state.messages, page.items);
        if (i == 0 && !hadSent) {
          // Chưa có lịch sử nào (lần tải đầu thất bại): coi như tải đầu tiên.
          _emit(_state.copyWith(
            messages: merged,
            hasMoreHistory: page.hasMore,
            nextCursor: page.hasMore
                ? (page.nextCursor ?? _oldestId(page.items))
                : null,
            error: null,
          ));
        } else {
          _emit(_state.copyWith(messages: merged, error: null));
        }
        if (!hadSent || overlap || !page.hasMore || page.nextCursor == null) {
          break;
        }
        before = page.nextCursor;
      }
    } catch (e) {
      if (_closed) return;
      _emit(_state.copyWith(error: errorMessageOf(e)));
    }
  }
}
