import 'package:test/test.dart';
import 'package:tv4_prep/tv4_prep.dart';

import 'test_support.dart';

const String _conv = 'cnv_01JCONV1';
const String _buyer = 'usr_01JBUYER1';
const String _seller = 'usr_01JABC123';

class _Env {
  _Env({
    required this.repo,
    required this.socket,
    required this.delay,
    required this.outbox,
    required this.controller,
  });

  final FakeChatRepository repo;
  final FakeChatSocket socket;
  final FakeDelay delay;
  final Outbox outbox;
  final ChatController controller;

  ChatState get state => controller.state;

  List<Message> byText(String text) =>
      state.messages.where((m) => m.text == text).toList();
}

_Env _makeEnv({
  String userId = _buyer,
  Outbox? outbox,
  FakeDelay? delay,
  bool initialReadOnly = false,
  int maxReconnectAttempts = 10,
}) {
  final repo = FakeChatRepository();
  final socket = FakeChatSocket(repository: repo, userId: userId);
  final fakeDelay = delay ?? FakeDelay();
  final box = outbox ?? Outbox();
  final ids = FakeIds();
  final controller = ChatController(
    conversationId: _conv,
    userId: userId,
    repository: repo,
    socket: socket,
    outbox: box,
    clock: fakeClock(start: DateTime.utc(2026, 11, 27, 10)),
    newClientMessageId: ids.next,
    delay: fakeDelay.call,
    maxReconnectAttempts: maxReconnectAttempts,
    initialReadOnly: initialReadOnly,
  );
  addTearDown(() async {
    await controller.dispose();
    await socket.dispose();
  });
  return _Env(
    repo: repo,
    socket: socket,
    delay: fakeDelay,
    outbox: box,
    controller: controller,
  );
}

Message peerMessage(
  String id,
  DateTime at, {
  String conversationId = _conv,
  String text = 'Chao ban',
}) =>
    Message(
      id: id,
      conversationId: conversationId,
      senderId: _seller,
      type: MessageType.text,
      text: text,
      createdAt: at,
    );

void main() {
  group('start', () {
    test('kết nối, tải lịch sử và đánh dấu đã đọc', () async {
      final e = _makeEnv();
      await e.controller.start();

      expect(e.state.connection, ChatConnectionStatus.connected);
      expect(e.socket.isConnected, isTrue);
      expect(e.state.messages.map((m) => m.id), ['msg_01JMESSAGE1']);
      expect(e.state.readOnly, isFalse);
      expect(e.repo.markReadCalls, 1);
    });

    test('states phát các thay đổi state', () async {
      final e = _makeEnv();
      final seen = <ChatState>[];
      final sub = e.controller.states.listen(seen.add);
      await e.controller.start();
      await pump();

      expect(seen, isNotEmpty);
      expect(seen.last.connection, ChatConnectionStatus.connected);
      expect(seen.last.messages, hasLength(1));
      await sub.cancel();
    });

    test('tin outbox còn lại của user được nạp lại và gửi khi start', () async {
      final box = Outbox()
        ..add(
          _buyer,
          OutboxEntry(
            clientMessageId: 'old-1',
            conversationId: _conv,
            text: 'tu phien truoc',
            createdAt: DateTime.utc(2026, 11, 27, 9),
          ),
        );
      final e = _makeEnv(outbox: box);
      await e.controller.start();
      await pump();

      expect(e.socket.sent.map((f) => f.clientMessageId), ['old-1']);
      final restored = e.byText('tu phien truoc');
      expect(restored, hasLength(1));
      expect(restored.single.sendStatus, SendStatus.sent);
      expect(box.entriesFor(_buyer), isEmpty);
    });
  });

  group('gửi tin online', () {
    test('pending rồi sent khi nhận ACK', () async {
      final e = _makeEnv();
      await e.controller.start();
      e.socket.ackEnabled = false;

      expect(await e.controller.send('  Xin chao  '), isNull);
      await pump();

      var last = e.state.messages.last;
      expect(last.text, 'Xin chao'); // đã trim
      expect(last.sendStatus, SendStatus.pending);
      expect(last.clientMessageId, 'cid-1');
      expect(e.outbox.entriesFor(_buyer), hasLength(1));
      expect(e.socket.sent.single.clientMessageId, 'cid-1');
      expect(e.socket.sent.single.text, 'Xin chao');

      e.socket.emit(MessageAck(
        clientMessageId: 'cid-1',
        messageId: 'msg_srv_1',
        createdAt: DateTime.utc(2026, 11, 27, 10, 5),
      ));
      await pump();

      expect(e.state.messages, hasLength(2));
      last = e.state.messages.last;
      expect(last.id, 'msg_srv_1');
      expect(last.sendStatus, SendStatus.sent);
      expect(last.createdAt, DateTime.utc(2026, 11, 27, 10, 5));
      expect(e.outbox.entriesFor(_buyer), isEmpty);
    });

    test('ACK tự động từ fake server: tin được lưu đúng một lần', () async {
      final e = _makeEnv();
      await e.controller.start();

      await e.controller.send('hello');
      await pump();

      final hello = e.byText('hello');
      expect(hello, hasLength(1));
      expect(hello.single.sendStatus, SendStatus.sent);
      expect(hello.single.id, startsWith('msg_fake_'));
      expect(e.outbox.entriesFor(_buyer), isEmpty);
      expect(e.repo.messagesOf(_conv), hasLength(2));
    });

    test('từ chối tin rỗng, quá dài; không đụng tới socket và outbox', () async {
      final e = _makeEnv();
      await e.controller.start();

      expect(await e.controller.send('   '), isNotNull);
      expect(await e.controller.send('a' * (kMessageMaxLength + 1)), isNotNull);
      await pump();

      expect(e.socket.sent, isEmpty);
      expect(e.outbox.entriesFor(_buyer), isEmpty);
      expect(e.state.messages, hasLength(1));
    });
  });

  group('offline và reconnect', () {
    test('gửi offline rồi reconnect: gửi một lần, không nhân đôi', () async {
      final delay = FakeDelay(manual: true);
      final e = _makeEnv(delay: delay);
      e.socket.offline = true;
      await e.controller.start();

      expect(e.state.connection, ChatConnectionStatus.reconnecting);
      expect(delay.requested, [const Duration(seconds: 1)]);

      expect(await e.controller.send('hi'), isNull);
      final pending = e.byText('hi').single;
      expect(pending.sendStatus, SendStatus.pending);
      expect(e.socket.sent, isEmpty);
      expect(e.outbox.entriesFor(_buyer), hasLength(1));

      e.socket.offline = false;
      delay.release();
      await pump();

      expect(e.state.connection, ChatConnectionStatus.connected);
      expect(e.socket.sent, hasLength(1));
      expect(e.socket.sent.single.clientMessageId, pending.clientMessageId);
      final hi = e.byText('hi');
      expect(hi, hasLength(1));
      expect(hi.single.sendStatus, SendStatus.sent);
      expect(e.outbox.entriesFor(_buyer), isEmpty);
      expect(e.repo.messagesOf(_conv).where((m) => m.text == 'hi'), hasLength(1));
    });

    test('mất ACK: gửi lại cùng clientMessageId, server không tạo tin trùng',
        () async {
      final delay = FakeDelay(manual: true);
      final e = _makeEnv(delay: delay);
      await e.controller.start();
      e.socket.ackEnabled = false; // server lưu nhưng ACK không tới

      await e.controller.send('A');
      await pump();
      expect(e.byText('A').single.sendStatus, SendStatus.pending);
      expect(e.repo.messagesOf(_conv).where((m) => m.text == 'A'), hasLength(1));

      e.socket.simulateDisconnect();
      await pump();
      expect(e.state.connection, ChatConnectionStatus.reconnecting);
      expect(delay.requested, [const Duration(seconds: 1)]);

      delay.release();
      await pump();

      expect(e.state.connection, ChatConnectionStatus.connected);
      expect(
        e.socket.sent.map((f) => f.clientMessageId).toList(),
        ['cid-1', 'cid-1'],
      );
      final a = e.byText('A');
      expect(a, hasLength(1));
      expect(a.single.sendStatus, SendStatus.sent);
      expect(e.outbox.entriesFor(_buyer), isEmpty);
      expect(e.repo.messagesOf(_conv).where((m) => m.text == 'A'), hasLength(1));
    });

    test('backoff 1s, 2s, 4s, 8s rồi bỏ cuộc; reconnect() thử lại từ đầu',
        () async {
      final delay = FakeDelay();
      final e = _makeEnv(delay: delay, maxReconnectAttempts: 4);
      e.socket.offline = true;
      await e.controller.start();
      await pump();

      expect(delay.requested, const [
        Duration(seconds: 1),
        Duration(seconds: 2),
        Duration(seconds: 4),
        Duration(seconds: 8),
      ]);
      expect(e.socket.connectCalls, 5); // 1 lần đầu + 4 lần nối lại
      expect(e.state.connection, ChatConnectionStatus.disconnected);

      e.socket.offline = false;
      e.controller.reconnect();
      await pump();

      expect(e.state.connection, ChatConnectionStatus.connected);
      expect(delay.requested.last, const Duration(seconds: 1));
    });

    test('nối lại thành công thì backoff được reset', () async {
      final delay = FakeDelay();
      final e = _makeEnv(delay: delay);
      e.socket.failConnectTimes = 3;
      await e.controller.start();
      await pump();

      expect(delay.requested, const [
        Duration(seconds: 1),
        Duration(seconds: 2),
        Duration(seconds: 4),
      ]);
      expect(e.state.connection, ChatConnectionStatus.connected);
      expect(e.socket.connectCalls, 4);

      e.socket.simulateDisconnect();
      await pump();

      expect(delay.requested, hasLength(4));
      expect(delay.requested.last, const Duration(seconds: 1));
      expect(e.state.connection, ChatConnectionStatus.connected);
    });

    test('sau reconnect tải lại lịch sử qua REST để lấp khoảng trống', () async {
      final e = _makeEnv();
      await e.controller.start();

      for (var i = 1; i <= 3; i++) {
        e.repo.addMessage(peerMessage(
          'msg_gap_$i',
          DateTime.utc(2026, 11, 27, 5, i),
          text: 'gap $i',
        ));
      }
      e.socket.simulateDisconnect();
      await pump();

      expect(e.state.connection, ChatConnectionStatus.connected);
      expect(e.state.messages, hasLength(4));
      expect(
        e.state.messages.map((m) => m.id),
        ['msg_01JMESSAGE1', 'msg_gap_1', 'msg_gap_2', 'msg_gap_3'],
      );
    });

    test('close code 4401: vẫn nối lại có backoff', () async {
      final delay = FakeDelay();
      final e = _makeEnv(delay: delay);
      await e.controller.start();

      e.socket.simulateDisconnect(closeCode: kWsCloseUnauthenticated);
      await pump();

      expect(e.state.readOnly, isFalse);
      expect(e.state.connection, ChatConnectionStatus.connected);
      expect(delay.requested, [const Duration(seconds: 1)]);
    });

    test('hết số lần thử thì failed; retryFailed gửi lại cùng clientMessageId',
        () async {
      final e = _makeEnv(outbox: Outbox(maxAttempts: 2));
      await e.controller.start();
      e.socket.dropSends = true; // server không nhận gì

      await e.controller.send('lost');
      await pump();
      expect(e.byText('lost').single.sendStatus, SendStatus.pending);

      e.socket.simulateDisconnect();
      await pump();

      // Lần gửi thứ 2 cũng không có ACK => failed, không retry vô hạn.
      expect(e.socket.sent, hasLength(2));
      expect(e.byText('lost').single.sendStatus, SendStatus.failed);
      expect(e.outbox.entriesFor(_buyer).single.status, SendStatus.failed);
      expect(e.outbox.retryable(_buyer), isEmpty);

      e.socket.dropSends = false;
      await e.controller.retryFailed();
      await pump();

      expect(e.socket.sent, hasLength(3));
      expect(
        e.socket.sent.map((f) => f.clientMessageId).toSet(),
        {'cid-1'},
      );
      final lost = e.byText('lost');
      expect(lost, hasLength(1));
      expect(lost.single.sendStatus, SendStatus.sent);
      expect(e.outbox.entriesFor(_buyer), isEmpty);
    });
  });

  group('tin nhận', () {
    test('MessageNew được merge và không trùng khi nhận lại', () async {
      final e = _makeEnv();
      await e.controller.start();
      final incoming = peerMessage('msg_in_1', DateTime.utc(2026, 11, 27, 4, 2));

      e.socket.simulateIncoming(incoming);
      await pump();
      expect(e.state.messages.map((m) => m.id), ['msg_01JMESSAGE1', 'msg_in_1']);

      // Cùng tin đến lần hai (vd qua REST rồi WebSocket).
      e.socket.emit(MessageNew(conversationId: _conv, message: incoming));
      await pump();
      expect(e.state.messages, hasLength(2));
    });

    test('bỏ qua tin của hội thoại khác', () async {
      final e = _makeEnv();
      await e.controller.start();

      e.socket.emit(MessageNew(
        conversationId: 'cnv_other',
        message: peerMessage(
          'msg_other',
          DateTime.utc(2026, 11, 27, 4, 3),
          conversationId: 'cnv_other',
        ),
      ));
      await pump();

      expect(e.state.messages, hasLength(1));
    });
  });

  group('read-only (AC-CHAT-09)', () {
    test('lỗi socket không retry được: pending -> failed, phòng read-only',
        () async {
      final e = _makeEnv();
      await e.controller.start();
      e.socket.dropSends = true;
      await e.controller.send('x');
      await pump();
      expect(e.byText('x').single.sendStatus, SendStatus.pending);

      e.socket.emit(const SocketError(code: 'ACCOUNT_BANNED', retryable: false));
      await pump();

      expect(e.state.readOnly, isTrue);
      expect(e.state.error, kMsgChatReadOnly);
      expect(e.byText('x').single.sendStatus, SendStatus.failed);
      expect(e.outbox.entriesFor(_buyer).single.status, SendStatus.failed);
      expect(e.outbox.retryable(_buyer), isEmpty);

      final framesBefore = e.socket.sent.length;
      expect(await e.controller.send('y'), kMsgChatReadOnly);
      await e.controller.retryFailed();
      await pump();
      expect(e.socket.sent, hasLength(framesBefore));
      expect(e.byText('y'), isEmpty);
    });

    test('server báo hội thoại read-only dù retryable = true', () async {
      final e = _makeEnv();
      await e.controller.start();

      e.socket.emit(const SocketError(
        code: 'CONVERSATION_READ_ONLY',
        retryable: true,
      ));
      await pump();

      expect(e.state.readOnly, isTrue);
    });

    test('lỗi retry được không khóa phòng', () async {
      final e = _makeEnv();
      await e.controller.start();

      e.socket.emit(const SocketError(code: 'INTERNAL', retryable: true));
      await pump();

      expect(e.state.readOnly, isFalse);
      expect(e.state.error, kMsgGeneric);
    });

    test('lỗi của hội thoại khác bị bỏ qua', () async {
      final e = _makeEnv();
      await e.controller.start();

      e.socket.emit(const SocketError(
        code: 'ACCOUNT_BANNED',
        retryable: false,
        conversationId: 'cnv_other',
      ));
      await pump();

      expect(e.state.readOnly, isFalse);
    });

    test('close code 4403: read-only và không nối lại', () async {
      final delay = FakeDelay();
      final e = _makeEnv(delay: delay);
      await e.controller.start();

      e.socket.simulateDisconnect(closeCode: kWsCloseForbidden);
      await pump();

      expect(e.state.readOnly, isTrue);
      expect(e.state.connection, ChatConnectionStatus.disconnected);
      expect(delay.requested, isEmpty);
      expect(e.socket.connectCalls, 1);
    });

    test('initialReadOnly: không cho gửi', () async {
      final e = _makeEnv(initialReadOnly: true);
      await e.controller.start();

      expect(await e.controller.send('hi'), kMsgChatReadOnly);
      expect(e.socket.sent, isEmpty);
    });
  });

  group('logout và đổi user (AC-CHAT-08)', () {
    test('logout xóa outbox, xóa state, đóng socket', () async {
      final delay = FakeDelay(manual: true);
      final e = _makeEnv(delay: delay);
      e.socket.offline = true;
      await e.controller.start();
      await e.controller.send('secret');
      expect(e.outbox.entriesFor(_buyer), hasLength(1));

      await e.controller.logout();

      expect(e.outbox.entriesFor(_buyer), isEmpty);
      expect(e.state.messages, isEmpty);
      expect(e.state.connection, ChatConnectionStatus.disconnected);
      expect(e.socket.closeCalls, 1);
      expect(await e.controller.send('more'), isNotNull);
      expect(e.outbox.entriesFor(_buyer), isEmpty);
    });

    test('đổi user: outbox của A không bao giờ được gửi bằng B', () async {
      final shared = Outbox();

      final a = _makeEnv(
        userId: 'usr_A',
        outbox: shared,
        delay: FakeDelay(manual: true),
      );
      a.socket.offline = true;
      await a.controller.start();
      await a.controller.send('secret from A');
      expect(shared.entriesFor('usr_A'), hasLength(1));
      // Chính sách "giữ local": A đăng xuất nhưng không xóa outbox.
      await a.controller.logout(clearOutbox: false);
      expect(shared.entriesFor('usr_A'), hasLength(1));

      final b = _makeEnv(userId: 'usr_B', outbox: shared);
      await b.controller.start();
      await pump();

      expect(b.socket.sent, isEmpty);
      expect(b.state.messages.where((m) => m.text.contains('secret')), isEmpty);
      expect(shared.entriesFor('usr_B'), isEmpty);
      expect(shared.entriesFor('usr_A'), hasLength(1)); // không bị đụng tới

      // B gửi tin của chính B vẫn bình thường.
      await b.controller.send('hello from B');
      await pump();
      expect(b.socket.sent.map((f) => f.text), ['hello from B']);
      expect(shared.entriesFor('usr_A'), hasLength(1));
    });

    test('socket của A bị ngắt thì không còn phản ứng với event', () async {
      final e = _makeEnv();
      await e.controller.start();
      await e.controller.logout();

      e.socket.emit(MessageNew(
        conversationId: _conv,
        message: peerMessage('msg_late', DateTime.utc(2026, 11, 27, 4, 9)),
      ));
      await pump();

      expect(e.state.messages, isEmpty);
    });
  });

  group('lịch sử theo cursor', () {
    test('trang mới nhất trước, rồi trang cũ hơn theo cursor', () async {
      final e = _makeEnv();
      for (var i = 1; i <= 35; i++) {
        e.repo.addMessage(peerMessage(
          'm${i.toString().padLeft(2, '0')}',
          DateTime.utc(2026, 11, 26, 0, i),
          text: 't$i',
        ));
      }
      await e.controller.start();

      expect(e.state.messages, hasLength(kHistoryDefaultLimit));
      expect(e.state.hasMoreHistory, isTrue);
      expect(e.state.nextCursor, e.state.messages.first.id);
      expect(e.repo.fetchMessagesCalls, 1);

      await e.controller.loadHistory();

      expect(e.state.messages, hasLength(36)); // 35 + tin mẫu
      expect(e.state.hasMoreHistory, isFalse);
      expect(e.state.nextCursor, isNull);
      expect(e.repo.fetchMessagesCalls, 2);

      await e.controller.loadHistory(); // đã hết: không gọi thêm
      expect(e.repo.fetchMessagesCalls, 2);
    });

    test('lỗi mạng khi tải lịch sử: thông báo tiếng Việt, thử lại được', () async {
      final e = _makeEnv();
      e.repo.faults.offline = true;
      await e.controller.start();

      expect(e.state.error, kMsgOffline);
      expect(e.state.loadingHistory, isFalse);
      expect(e.state.hasMoreHistory, isTrue);
      expect(e.state.messages, isEmpty);

      e.repo.faults.offline = false;
      await e.controller.loadHistory();

      expect(e.state.error, isNull);
      expect(e.state.messages, hasLength(1));
    });

    test('items chèn phân cách ngày', () async {
      final e = _makeEnv();
      await e.controller.start();

      final items = e.state.items;
      expect(items.first, isA<DateDivider>());
      expect(items.whereType<MessageItem>(), hasLength(1));
    });
  });
}
