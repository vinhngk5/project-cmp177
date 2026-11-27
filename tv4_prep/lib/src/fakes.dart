/// Cài đặt in-memory của các repository / socket để dev UI và viết test mà
/// không cần backend. Dữ liệu mẫu lấy từ JSON mẫu trong docs/API.md.
///
/// Mọi fake có `faults` để mô phỏng lỗi (offline, lỗi một lần, lỗi kéo dài) và
/// một vài công tắc riêng (xem từng class). Lỗi được ném dưới dạng
/// [ApiException] giống bản HTTP thật.
library;

import 'dart:async';

import 'api_error.dart';
import 'constants.dart';
import 'enums.dart';
import 'models.dart';
import 'repositories.dart';

/// Đồng hồ giả tăng dần mỗi lần gọi 1 giây, để thứ tự tin nhắn xác định.
DateTime Function() fakeClock({DateTime? start}) {
  var t = start ?? DateTime.utc(2026, 11, 27, 12);
  return () {
    t = t.add(const Duration(seconds: 1));
    return t;
  };
}

/// Công tắc lỗi dùng chung cho các fake repository.
class FakeFaults {
  /// true: mọi lời gọi ném lỗi mạng (E-01).
  bool offline = false;

  /// Lỗi ném ở MỌI lời gọi cho tới khi gán lại null.
  ApiException? error;

  final List<ApiException> _once = <ApiException>[];

  /// Lỗi chỉ ném ở lời gọi kế tiếp (có thể xếp hàng nhiều lỗi).
  void failOnce(ApiException e) => _once.add(e);

  /// Gọi ở đầu mỗi method của fake.
  void check() {
    if (offline) throw ApiException.network();
    if (_once.isNotEmpty) throw _once.removeAt(0);
    final e = error;
    if (e != null) throw e;
  }
}

PageResult<T> _slice<T>(List<T> all, int page, int pageSize) {
  final size = pageSize < 1 ? 1 : pageSize;
  final p = page < 1 ? 1 : page;
  final start = (p - 1) * size;
  final items = start >= all.length
      ? <T>[]
      : all.sublist(start, start + size > all.length ? all.length : start + size);
  return PageResult<T>(
    items: items,
    page: p,
    pageSize: size,
    totalItems: all.length,
    hasMore: p * size < all.length,
  );
}

// ---------------------------------------------------------------------------
// Chat
// ---------------------------------------------------------------------------

class FakeChatRepository implements ChatRepository {
  /// [seed] = true nạp dữ liệu mẫu của API.md mục 4.6 / 6.6.
  FakeChatRepository({bool seed = true, DateTime Function()? clock})
      : _clock = clock ?? fakeClock() {
    if (seed) {
      conversations.add(ConversationSummary.fromJson({
        'id': 'cnv_01JCONV1',
        'product_id': 'prd_01JPRODUCT1',
        'product_title': 'Giao trinh Giai tich 1',
        'other_participant': {
          'id': 'usr_01JABC123',
          'display_name': 'Nguyen Van A',
        },
        'last_message': {
          'text': 'Minh hen 5h nhe',
          'created_at': '2026-11-27T04:30:00Z',
        },
        'unread_count': 2,
      }));
      addMessage(Message.fromJson({
        'id': 'msg_01JMESSAGE1',
        'conversation_id': 'cnv_01JCONV1',
        'sender_id': 'usr_01JBUYER1',
        'type': 'TEXT',
        'text': 'Mon nay con khong ban?',
        'client_message_id': 'local-uuid-123',
        'created_at': '2026-11-27T04:01:00Z',
        'read_at': null,
      }));
    }
  }

  final DateTime Function() _clock;
  final FakeFaults faults = FakeFaults();
  final List<ConversationSummary> conversations = <ConversationSummary>[];
  final Map<String, List<Message>> _messages = <String, List<Message>>{};
  int _convSeq = 0;

  int listCalls = 0;
  int openCalls = 0;
  int fetchMessagesCalls = 0;
  int markReadCalls = 0;

  /// Thêm tin vào "server". Bỏ qua nếu trùng id hoặc trùng (sender, client_message_id).
  void addMessage(Message m) {
    final list = _messages.putIfAbsent(m.conversationId, () => <Message>[]);
    final cid = m.clientMessageId;
    final duplicate = list.any((x) =>
        x.id == m.id ||
        (cid != null && x.clientMessageId == cid && x.senderId == m.senderId));
    if (duplicate) return;
    list.add(m);
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Message? findByClientId(String senderId, String clientMessageId) {
    for (final list in _messages.values) {
      for (final m in list) {
        if (m.senderId == senderId && m.clientMessageId == clientMessageId) {
          return m;
        }
      }
    }
    return null;
  }

  List<Message> messagesOf(String conversationId) =>
      List<Message>.unmodifiable(_messages[conversationId] ?? const <Message>[]);

  @override
  Future<PageResult<ConversationSummary>> listConversations(
    int page, {
    int pageSize = 20,
  }) async {
    listCalls++;
    faults.check();
    return _slice<ConversationSummary>(conversations, page, pageSize);
  }

  @override
  Future<ConversationRef> openConversation(String productId) async {
    openCalls++;
    faults.check();
    for (final c in conversations) {
      if (c.productId == productId) {
        return ConversationRef(
          id: c.id,
          productId: productId,
          buyerId: 'usr_01JBUYER1',
          sellerId: c.other.id,
          createdAt: _clock(),
          isNew: false,
        );
      }
    }
    _convSeq++;
    final id = 'cnv_fake_$_convSeq';
    conversations.add(ConversationSummary(
      id: id,
      productId: productId,
      productTitle: '',
      other: const Participant(
        id: 'usr_01JABC123',
        displayName: 'Nguyen Van A',
      ),
      unreadCount: 0,
    ));
    return ConversationRef(
      id: id,
      productId: productId,
      buyerId: 'usr_01JBUYER1',
      sellerId: 'usr_01JABC123',
      createdAt: _clock(),
      isNew: true,
    );
  }

  /// Trang tin theo cursor: [before] là id tin; trả tối đa [limit] tin cũ hơn nó
  /// (hoặc trang mới nhất nếu [before] null), thứ tự cũ -> mới.
  @override
  Future<PageResult<Message>> fetchMessages(
    String conversationId, {
    String? before,
    int limit = kHistoryDefaultLimit,
  }) async {
    fetchMessagesCalls++;
    faults.check();
    final all = [...?_messages[conversationId]]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    var end = all.length;
    if (before != null) {
      final i = all.indexWhere((m) => m.id == before);
      if (i >= 0) end = i;
    }
    final size = limit < 1
        ? 1
        : (limit > kHistoryMaxLimit ? kHistoryMaxLimit : limit);
    final start = end - size < 0 ? 0 : end - size;
    final slice = all.sublist(start, end);
    final more = start > 0;
    return PageResult<Message>(
      items: slice,
      pageSize: size,
      totalItems: all.length,
      hasMore: more,
      nextCursor: more ? slice.first.id : null,
    );
  }

  @override
  Future<ReadReceipt> markRead(String conversationId) async {
    markReadCalls++;
    faults.check();
    final idx = conversations.indexWhere((c) => c.id == conversationId);
    if (idx < 0) {
      throw ApiException(httpStatus: 404, code: 'CONVERSATION_NOT_FOUND');
    }
    final c = conversations[idx];
    conversations[idx] = ConversationSummary(
      id: c.id,
      productId: c.productId,
      productTitle: c.productTitle,
      other: c.other,
      lastMessage: c.lastMessage,
      unreadCount: 0,
      status: c.status,
    );
    return ReadReceipt(
      conversationId: conversationId,
      unreadCount: 0,
      lastReadAt: _clock(),
    );
  }
}

/// Khung `message.send` mà [FakeChatSocket] đã nhận.
class FakeSentFrame {
  const FakeSentFrame(this.conversationId, this.clientMessageId, this.text);

  final String conversationId;
  final String clientMessageId;
  final String text;
}

/// Socket giả đóng vai cả server: nhận `message.send`, lưu tin (idempotent theo
/// `client_message_id`, E-08), rồi phát `message.ack`.
class FakeChatSocket implements ChatSocket {
  /// [repository] (nếu có) là nơi "server" lưu tin, để REST history thấy tin đã
  /// gửi. [userId] là người gửi của các tin nhận qua [send].
  FakeChatSocket({
    this.repository,
    this.userId = 'usr_01JBUYER1',
    DateTime Function()? clock,
  }) : _clock = clock ?? fakeClock(start: DateTime.utc(2026, 11, 27, 11));

  final FakeChatRepository? repository;
  final String userId;
  final DateTime Function() _clock;

  final StreamController<ChatSocketEvent> _controller =
      StreamController<ChatSocketEvent>.broadcast();
  final Map<String, Message> _stored = <String, Message>{};
  bool _connected = false;
  int _seq = 0;

  /// true: [connect] ném lỗi mạng.
  bool offline = false;

  /// [connect] thất bại đúng chừng này lần rồi thành công.
  int failConnectTimes = 0;

  /// false: server vẫn lưu tin nhưng không phát ACK (mô phỏng mất ACK).
  bool ackEnabled = true;

  /// true: server không nhận gì cả (không lưu, không ACK).
  bool dropSends = false;

  int connectCalls = 0;
  int closeCalls = 0;

  /// Mọi khung đã gửi, kể cả gửi lại.
  final List<FakeSentFrame> sent = <FakeSentFrame>[];

  bool get isConnected => _connected;

  @override
  Stream<ChatSocketEvent> get events => _controller.stream;

  @override
  Future<void> connect() async {
    connectCalls++;
    if (offline) throw ApiException.network();
    if (failConnectTimes > 0) {
      failConnectTimes--;
      throw ApiException.network();
    }
    _connected = true;
  }

  @override
  Future<void> send(
    String conversationId,
    String clientMessageId,
    String text,
  ) async {
    if (!_connected) throw ApiException.network();
    sent.add(FakeSentFrame(conversationId, clientMessageId, text));
    if (dropSends) return;
    final message = _persist(conversationId, clientMessageId, text);
    if (ackEnabled) {
      emit(MessageAck(
        clientMessageId: clientMessageId,
        messageId: message.id,
        createdAt: message.createdAt,
      ));
    }
  }

  @override
  Future<void> close() async {
    closeCalls++;
    _connected = false;
  }

  Message _persist(String conversationId, String clientMessageId, String text) {
    final existing = repository?.findByClientId(userId, clientMessageId) ??
        _stored[clientMessageId];
    if (existing != null) return existing;
    _seq++;
    final message = Message(
      id: 'msg_fake_$_seq',
      conversationId: conversationId,
      senderId: userId,
      type: MessageType.text,
      text: text,
      createdAt: _clock(),
      clientMessageId: clientMessageId,
    );
    _stored[clientMessageId] = message;
    repository?.addMessage(message);
    return message;
  }

  /// Bơm một event bất kỳ như thể server vừa gửi.
  void emit(ChatSocketEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }

  /// Người kia gửi tin: lưu vào repository (nếu có) và phát `message.new`.
  void simulateIncoming(Message message) {
    repository?.addMessage(message);
    emit(MessageNew(conversationId: message.conversationId, message: message));
  }

  /// Ngắt kết nối từ phía server.
  void simulateDisconnect({int? closeCode}) {
    _connected = false;
    emit(Disconnected(closeCode: closeCode));
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

// ---------------------------------------------------------------------------
// Report
// ---------------------------------------------------------------------------

class FakeReportRepository implements ReportRepository {
  /// [seed] = true nạp report mẫu rpt_01JREPORT1 (PENDING, prd_01JPRODUCT1)
  /// nên báo cáo lại đúng Product đó sẽ nhận 409.
  FakeReportRepository({bool seed = true, DateTime Function()? clock})
      : _clock = clock ?? fakeClock() {
    if (seed) {
      _reports.add(MyReport.fromJson({
        'id': 'rpt_01JREPORT1',
        'product_id': 'prd_01JPRODUCT1',
        'product_title_snapshot': 'Giao trinh Giai tich 1',
        'reason': 'MISLEADING',
        'description': 'Anh va mo ta khong trung khop.',
        'status': 'PENDING',
        'created_at': '2026-11-27T06:00:00Z',
        'resolved_at': null,
        'resolution_note': null,
      }));
    }
  }

  final DateTime Function() _clock;
  final List<MyReport> _reports = <MyReport>[];
  int _seq = 0;
  int _createdByCreateCalls = 0;

  final FakeFaults faults = FakeFaults();

  /// Công tắc: ép 409 REPORT_ALREADY_PENDING ở createReport.
  bool forceAlreadyPending = false;

  /// Công tắc: ép 429 REPORT_RATE_LIMITED (kèm [rateLimitRetryAfter]).
  bool forceRateLimited = false;
  Duration rateLimitRetryAfter = const Duration(hours: 1);

  /// Hạn mức tự nhiên: quá số report tạo qua createReport thì 429 (OQ-13).
  int dailyLimit = kReportDailyLimit;

  /// Nếu gán, createReport chờ future này trước khi hoàn tất (giữ request
  /// "đang bay" để test khóa gửi).
  Completer<void>? gate;

  int createCalls = 0;
  String? lastProductId;
  ReportReason? lastReason;
  String? lastDescription;

  List<MyReport> get reports => List<MyReport>.unmodifiable(_reports);

  @override
  Future<MyReport> createReport(
    String productId,
    ReportReason reason,
    String? description,
  ) async {
    createCalls++;
    lastProductId = productId;
    lastReason = reason;
    lastDescription = description;
    final g = gate;
    if (g != null) await g.future;
    faults.check();
    if (forceAlreadyPending) {
      throw ApiException(httpStatus: 409, code: 'REPORT_ALREADY_PENDING');
    }
    if (forceRateLimited || _createdByCreateCalls >= dailyLimit) {
      throw ApiException(
        httpStatus: 429,
        code: 'REPORT_RATE_LIMITED',
        retryAfter: rateLimitRetryAfter,
      );
    }
    final duplicate = _reports.any(
      (r) => r.productId == productId && r.status == ReportStatus.pending,
    );
    if (duplicate) {
      throw ApiException(httpStatus: 409, code: 'REPORT_ALREADY_PENDING');
    }
    _seq++;
    _createdByCreateCalls++;
    final created = MyReport(
      id: 'rpt_fake_$_seq',
      productId: productId,
      reason: reason,
      description: description,
      status: ReportStatus.pending,
      createdAt: _clock(),
    );
    _reports.add(created);
    return created;
  }

  @override
  Future<PageResult<MyReport>> myReports(int page, {int pageSize = 20}) async {
    faults.check();
    final sorted = [..._reports]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return _slice<MyReport>(sorted, page, pageSize);
  }

  @override
  Future<MyReport> myReport(String id) async {
    faults.check();
    for (final r in _reports) {
      if (r.id == id) return r;
    }
    throw ApiException(httpStatus: 404, code: 'REPORT_NOT_FOUND');
  }
}

// ---------------------------------------------------------------------------
// Admin
// ---------------------------------------------------------------------------

class FakeAdminRepository implements AdminRepository {
  /// [seed] = true nạp report mẫu rpt_01JREPORT1 (PENDING) của API.md mục 6.9.
  FakeAdminRepository({bool seed = true, DateTime Function()? clock})
      : _clock = clock ?? fakeClock() {
    if (seed) {
      _items['rpt_01JREPORT1'] = AdminReportItem.fromJson({
        'id': 'rpt_01JREPORT1',
        'target_type': 'PRODUCT',
        'target_id': 'prd_01JPRODUCT1',
        'reason': 'MISLEADING',
        'status': 'PENDING',
        'created_at': '2026-11-27T06:00:00Z',
      });
      _details['rpt_01JREPORT1'] = AdminReportDetail.fromJson({
        'id': 'rpt_01JREPORT1',
        'reporter': {
          'display_name': 'Nguyen B',
          'joined_at': '2026-10-01T00:00:00Z',
        },
        'target': {
          'type': 'PRODUCT',
          'id': 'prd_01JPRODUCT1',
          'status': 'AVAILABLE',
        },
        'snapshot': {
          'title': 'Giao trinh Giai tich 1',
          'price_vnd': 45000,
          'cover_image_url': null,
        },
        'reason': 'MISLEADING',
        'description': 'Thong tin khong trung khop.',
        'status': 'PENDING',
      });
    }
  }

  final DateTime Function() _clock;
  final Map<String, AdminReportItem> _items = <String, AdminReportItem>{};
  final Map<String, AdminReportDetail> _details =
      <String, AdminReportDetail>{};

  final FakeFaults faults = FakeFaults();

  /// Công tắc: false => mọi lời gọi nhận 403 ADMIN_REQUIRED (AC-ADMIN-01).
  bool isAdmin = true;

  /// Id của Admin đang đăng nhập; ban chính mình => 409 ADMIN_SELF_BAN_FORBIDDEN.
  String adminUserId = 'usr_01JADMIN1';

  int resolveCalls = 0;
  AdminAction? lastAction;
  String? lastNote;
  final List<String> bannedUserIds = <String>[];

  /// Thêm một report vào hàng đợi.
  void addReport({
    required String id,
    ReportStatus status = ReportStatus.pending,
    ReportReason reason = ReportReason.misleading,
    String productId = 'prd_fake',
    String title = 'Tin mau',
  }) {
    final created = _clock();
    _items[id] = AdminReportItem(
      id: id,
      targetType: 'PRODUCT',
      targetId: productId,
      reason: reason,
      status: status,
      createdAt: created,
    );
    _details[id] = AdminReportDetail(
      id: id,
      reporterName: 'Nguyen B',
      targetId: productId,
      targetStatus: 'AVAILABLE',
      snapshotTitle: title,
      snapshotPriceVnd: 45000,
      reason: reason,
      status: status,
    );
  }

  /// Thêm [count] report PENDING có id rpt_fake_1..count (để thử phân trang).
  void seedReports(int count) {
    for (var i = 1; i <= count; i++) {
      addReport(id: 'rpt_fake_$i', productId: 'prd_fake_$i');
    }
  }

  /// Mô phỏng Admin khác vừa xử lý report (E-16): lần resolve kế tiếp sẽ nhận
  /// 409 REPORT_ALREADY_RESOLVED.
  void markResolvedElsewhere(String id,
      {ReportStatus status = ReportStatus.resolved}) {
    final item = _items[id];
    final detail = _details[id];
    if (item != null) _items[id] = item.withStatus(status);
    if (detail != null) _details[id] = detail.withStatus(status);
  }

  void _guard() {
    faults.check();
    if (!isAdmin) {
      throw ApiException(httpStatus: 403, code: 'ADMIN_REQUIRED');
    }
  }

  @override
  Future<PageResult<AdminReportItem>> listReports(
    ReportStatus? status,
    int page, {
    int pageSize = 20,
  }) async {
    _guard();
    final filtered = [
      for (final i in _items.values)
        if (status == null || i.status == status) i,
    ];
    return _slice<AdminReportItem>(filtered, page, pageSize);
  }

  @override
  Future<AdminReportDetail> reportDetail(String id) async {
    _guard();
    final d = _details[id];
    if (d == null) {
      throw ApiException(httpStatus: 404, code: 'REPORT_NOT_FOUND');
    }
    return d;
  }

  @override
  Future<ResolveResult> resolve(
    String id,
    AdminAction action,
    String note,
  ) async {
    resolveCalls++;
    lastAction = action;
    lastNote = note;
    _guard();
    final detail = _details[id];
    final item = _items[id];
    if (detail == null || item == null) {
      throw ApiException(httpStatus: 404, code: 'REPORT_NOT_FOUND');
    }
    if (detail.status != ReportStatus.pending) {
      throw ApiException(httpStatus: 409, code: 'REPORT_ALREADY_RESOLVED');
    }
    final newStatus = action == AdminAction.rejectReport
        ? ReportStatus.rejected
        : ReportStatus.resolved;
    _items[id] = item.withStatus(newStatus);
    _details[id] = detail.withStatus(newStatus);
    return ResolveResult(
      reportId: id,
      reportStatus: newStatus,
      action: action,
      productStatus: action == AdminAction.rejectReport ? 'AVAILABLE' : 'BLOCKED',
      ownerStatus:
          action == AdminAction.removeProductAndBanOwner ? 'BANNED' : 'ACTIVE',
      resolvedAt: _clock(),
    );
  }

  @override
  Future<BanResult> banUser(String userId, String reason) async {
    _guard();
    if (userId == adminUserId) {
      throw ApiException(httpStatus: 409, code: 'ADMIN_SELF_BAN_FORBIDDEN');
    }
    bannedUserIds.add(userId);
    return BanResult(
      userId: userId,
      status: 'BANNED',
      banReason: reason,
      bannedAt: _clock(),
    );
  }
}
