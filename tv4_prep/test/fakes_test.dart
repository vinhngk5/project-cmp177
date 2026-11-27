import 'package:test/test.dart';
import 'package:tv4_prep/tv4_prep.dart';

import 'test_support.dart';

Future<ApiException> catchApi(Future<void> Function() body) async {
  try {
    await body();
  } on ApiException catch (e) {
    return e;
  }
  fail('Mong đợi ApiException nhưng không có lỗi nào');
}

void main() {
  group('FakeChatRepository', () {
    test('dữ liệu mẫu khớp API.md', () async {
      final repo = FakeChatRepository();

      final list = await repo.listConversations(1);
      expect(list.items.single.id, 'cnv_01JCONV1');
      expect(list.items.single.unreadCount, 2);
      expect(list.totalItems, 1);
      expect(list.hasMore, isFalse);

      final msgs = await repo.fetchMessages('cnv_01JCONV1');
      expect(msgs.items.single.id, 'msg_01JMESSAGE1');
      expect(msgs.items.single.clientMessageId, 'local-uuid-123');
      expect(msgs.hasMore, isFalse);
      expect(msgs.nextCursor, isNull);
    });

    test('openConversation: lần đầu tạo mới, lần sau trả lại hội thoại cũ',
        () async {
      final repo = FakeChatRepository();

      final existing = await repo.openConversation('prd_01JPRODUCT1');
      expect(existing.id, 'cnv_01JCONV1');
      expect(existing.isNew, isFalse);

      final created = await repo.openConversation('prd_moi');
      expect(created.isNew, isTrue);
      final again = await repo.openConversation('prd_moi');
      expect(again.id, created.id);
      expect(again.isNew, isFalse);
    });

    test('markRead đưa unread về 0', () async {
      final repo = FakeChatRepository();

      final receipt = await repo.markRead('cnv_01JCONV1');

      expect(receipt.unreadCount, 0);
      expect((await repo.listConversations(1)).items.single.unreadCount, 0);
    });

    test('lỗi: offline và lỗi một lần', () async {
      final repo = FakeChatRepository();

      repo.faults.offline = true;
      final off = await catchApi(() => repo.listConversations(1));
      expect(off.isNetwork, isTrue);
      expect(off.message, kMsgOffline);

      repo.faults.offline = false;
      repo.faults.failOnce(ApiException(httpStatus: 404, code: 'PRODUCT_NOT_FOUND'));
      final gone = await catchApi(() => repo.openConversation('x'));
      expect(gone.message, kMsgProductGone);
      expect((await repo.openConversation('x')).isNew, isTrue); // chỉ lỗi một lần
    });
  });

  group('FakeChatSocket', () {
    test('send khi chưa kết nối ném lỗi mạng', () async {
      final socket = FakeChatSocket();
      addTearDown(socket.dispose);

      final e = await catchApi(() => socket.send('c', 'cid', 'hi'));

      expect(e.isNetwork, isTrue);
      expect(socket.sent, isEmpty);
    });

    test('gửi lại cùng clientMessageId: server idempotent, ACK cùng messageId',
        () async {
      final repo = FakeChatRepository();
      final socket = FakeChatSocket(repository: repo);
      addTearDown(socket.dispose);
      final acks = <MessageAck>[];
      final sub = socket.events.listen((e) {
        if (e is MessageAck) acks.add(e);
      });

      await socket.connect();
      await socket.send('cnv_01JCONV1', 'cid-x', 'hello');
      await socket.send('cnv_01JCONV1', 'cid-x', 'hello');
      await pump();

      expect(acks, hasLength(2));
      expect(acks[0].messageId, acks[1].messageId);
      expect(
        repo.messagesOf('cnv_01JCONV1').where((m) => m.clientMessageId == 'cid-x'),
        hasLength(1),
      );
      await sub.cancel();
    });

    test('bơm event, ngắt kết nối và failConnectTimes', () async {
      final socket = FakeChatSocket();
      addTearDown(socket.dispose);
      final seen = <ChatSocketEvent>[];
      final sub = socket.events.listen(seen.add);

      socket.failConnectTimes = 1;
      await catchApi(socket.connect);
      expect(socket.isConnected, isFalse);
      await socket.connect();
      expect(socket.isConnected, isTrue);
      expect(socket.connectCalls, 2);

      socket.emit(const SocketError(code: 'X', retryable: true));
      socket.simulateDisconnect(closeCode: kWsCloseForbidden);
      await pump();

      expect(socket.isConnected, isFalse);
      expect(seen, hasLength(2));
      expect(seen[0], isA<SocketError>());
      expect((seen[1] as Disconnected).closeCode, 4403);
      await sub.cancel();
    });
  });

  group('FakeReportRepository', () {
    test('tạo report, liệt kê và đọc chi tiết', () async {
      final repo = FakeReportRepository();

      final created = await repo.createReport(
        'prd_x',
        ReportReason.scam,
        'lua dao',
      );
      expect(created.status, ReportStatus.pending);

      final list = await repo.myReports(1);
      expect(list.totalItems, 2); // mẫu + vừa tạo
      expect(list.items.first.id, created.id); // mới nhất trước

      expect((await repo.myReport('rpt_01JREPORT1')).description,
          'Anh va mo ta khong trung khop.');
      final missing = await catchApi(() => repo.myReport('khong_co'));
      expect(missing.httpStatus, 404);
    });

    test('409 trùng PENDING và 429 quá hạn mức', () async {
      final repo = FakeReportRepository();

      final dup = await catchApi(
        () => repo.createReport('prd_01JPRODUCT1', ReportReason.spam, null),
      );
      expect(dup.httpStatus, 409);
      expect(dup.code, 'REPORT_ALREADY_PENDING');

      repo.forceRateLimited = true;
      final limited = await catchApi(
        () => repo.createReport('prd_y', ReportReason.spam, null),
      );
      expect(limited.httpStatus, 429);
      expect(limited.code, 'REPORT_RATE_LIMITED');
      expect(limited.retryAfter, isNotNull);
    });
  });

  group('FakeAdminRepository', () {
    test('danh sách, chi tiết, resolve và 409 khi resolve lần hai', () async {
      final repo = FakeAdminRepository();

      final list = await repo.listReports(ReportStatus.pending, 1);
      expect(list.items.single.id, 'rpt_01JREPORT1');

      final detail = await repo.reportDetail('rpt_01JREPORT1');
      expect(detail.canResolve, isTrue);

      final result = await repo.resolve(
        'rpt_01JREPORT1',
        AdminAction.removeProductAndBanOwner,
        'Product co dau hieu lua dao.',
      );
      expect(result.reportStatus, ReportStatus.resolved);
      expect(result.productStatus, 'BLOCKED');
      expect(result.ownerStatus, 'BANNED');
      expect((await repo.reportDetail('rpt_01JREPORT1')).canResolve, isFalse);
      expect((await repo.listReports(ReportStatus.pending, 1)).items, isEmpty);

      final again = await catchApi(
        () => repo.resolve('rpt_01JREPORT1', AdminAction.removeProduct, 'ghi chu hop le'),
      );
      expect(again.httpStatus, 409);
      expect(again.code, 'REPORT_ALREADY_RESOLVED');
    });

    test('403 ADMIN_REQUIRED khi không phải Admin', () async {
      final repo = FakeAdminRepository()..isAdmin = false;

      final e = await catchApi(() => repo.listReports(null, 1));

      expect(e.httpStatus, 403);
      expect(e.code, 'ADMIN_REQUIRED');
      expect(e.message, kMsgForbidden);
    });

    test('phân trang theo page/page_size', () async {
      final repo = FakeAdminRepository(seed: false)..seedReports(5);

      final p1 = await repo.listReports(null, 1, pageSize: 2);
      final p3 = await repo.listReports(null, 3, pageSize: 2);
      final p4 = await repo.listReports(null, 4, pageSize: 2);

      expect(p1.items, hasLength(2));
      expect(p1.hasMore, isTrue);
      expect(p1.totalItems, 5);
      expect(p3.items, hasLength(1));
      expect(p3.hasMore, isFalse);
      expect(p4.items, isEmpty);
    });
  });
}
