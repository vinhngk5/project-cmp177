import 'package:test/test.dart';
import 'package:tv4_prep/tv4_prep.dart';

Message msg(
  String id,
  DateTime at, {
  String? cid,
  SendStatus status = SendStatus.sent,
  String text = 't',
}) =>
    Message(
      id: id,
      conversationId: 'c1',
      senderId: 'u1',
      type: MessageType.text,
      text: text,
      createdAt: at,
      clientMessageId: cid,
      sendStatus: status,
    );

OutboxEntry entry(String cid, {String conv = 'c1', String text = 'hi'}) =>
    OutboxEntry(
      clientMessageId: cid,
      conversationId: conv,
      text: text,
      createdAt: DateTime.utc(2026, 11, 27),
    );

void main() {
  group('groupByDay', () {
    test('danh sách rỗng => rỗng', () {
      expect(groupByDay([]), isEmpty);
    });

    test('cùng ngày => 1 divider rồi các tin', () {
      final items = groupByDay([
        msg('a', DateTime(2026, 11, 27, 9)),
        msg('b', DateTime(2026, 11, 27, 10)),
      ]);
      expect(items.length, 3);
      expect(items[0], isA<DateDivider>());
      expect((items[0] as DateDivider).day, DateTime(2026, 11, 27));
      expect((items[1] as MessageItem).message.id, 'a');
      expect((items[2] as MessageItem).message.id, 'b');
    });

    test('sang ngày mới chèn divider, đầu vào lộn xộn được sắp xếp tăng dần',
        () {
      final items = groupByDay([
        msg('c', DateTime(2026, 11, 28, 8)),
        msg('a', DateTime(2026, 11, 26, 23, 59)),
        msg('b', DateTime(2026, 11, 27, 0, 1)),
      ]);
      expect(items.length, 6);
      expect(items[0], isA<DateDivider>());
      expect((items[0] as DateDivider).day, DateTime(2026, 11, 26));
      expect((items[1] as MessageItem).message.id, 'a');
      expect((items[2] as DateDivider).day, DateTime(2026, 11, 27));
      expect((items[3] as MessageItem).message.id, 'b');
      expect((items[4] as DateDivider).day, DateTime(2026, 11, 28));
      expect((items[5] as MessageItem).message.id, 'c');
    });

    test('không làm thay đổi danh sách đầu vào', () {
      final input = [
        msg('b', DateTime(2026, 11, 27, 10)),
        msg('a', DateTime(2026, 11, 27, 9)),
      ];
      groupByDay(input);
      expect(input.map((m) => m.id).toList(), ['b', 'a']);
    });

    test('mốc thời gian UTC được quy về ngày local', () {
      final t = DateTime.utc(2026, 11, 27, 4, 1);
      final l = t.toLocal();
      final items = groupByDay([msg('a', t)]);
      expect((items.first as DateDivider).day, DateTime(l.year, l.month, l.day));
    });
  });

  group('formatDividerLabel', () {
    final now = DateTime(2026, 11, 27, 15, 30);

    test('Hôm nay', () {
      expect(formatDividerLabel(DateTime(2026, 11, 27), now: now), 'Hôm nay');
      expect(formatDividerLabel(DateTime(2026, 11, 27, 23, 59), now: now),
          'Hôm nay');
    });

    test('Hôm qua', () {
      expect(formatDividerLabel(DateTime(2026, 11, 26), now: now), 'Hôm qua');
    });

    test('dd/MM/yyyy cho ngày cũ hơn, có padding số 0', () {
      expect(formatDividerLabel(DateTime(2026, 11, 25), now: now), '25/11/2026');
      expect(formatDividerLabel(DateTime(2026, 3, 5), now: now), '05/03/2026');
    });

    test('qua ranh giới năm', () {
      final newYear = DateTime(2027, 1, 1, 8);
      expect(formatDividerLabel(DateTime(2026, 12, 31), now: newYear),
          'Hôm qua');
      expect(formatDividerLabel(DateTime(2026, 12, 30), now: newYear),
          '30/12/2026');
    });

    test('ngày trong tương lai rơi về định dạng ngày', () {
      expect(formatDividerLabel(DateTime(2026, 11, 28), now: now), '28/11/2026');
    });
  });

  group('mergeMessages', () {
    final t0 = DateTime.utc(2026, 11, 27, 4, 0);
    final t1 = DateTime.utc(2026, 11, 27, 4, 1);
    final t2 = DateTime.utc(2026, 11, 27, 4, 2);

    test('rỗng + rỗng', () {
      expect(mergeMessages([], []), isEmpty);
    });

    test('khử trùng theo id và sắp xếp theo thời gian', () {
      final out = mergeMessages(
        [msg('b', t1), msg('a', t0)],
        [msg('b', t1), msg('c', t2)],
      );
      expect(out.map((m) => m.id).toList(), ['a', 'b', 'c']);
    });

    test('cùng id, bản incoming thay bản existing', () {
      final out = mergeMessages(
        [msg('a', t0, text: 'cu')],
        [msg('a', t0, text: 'moi')],
      );
      expect(out.length, 1);
      expect(out.single.text, 'moi');
    });

    test('bản server thay bản pending cùng clientMessageId, không nhân đôi',
        () {
      final pending =
          msg('local-1', t0, cid: 'cid-1', status: SendStatus.pending);
      final server = msg('msg_1', t1, cid: 'cid-1');
      final out = mergeMessages([pending], [server]);
      expect(out.length, 1);
      expect(out.single.id, 'msg_1');
      expect(out.single.sendStatus, SendStatus.sent);
    });

    test('bản server thay bản failed cùng clientMessageId', () {
      final failed =
          msg('local-1', t0, cid: 'cid-1', status: SendStatus.failed);
      final out = mergeMessages([failed], [msg('msg_1', t1, cid: 'cid-1')]);
      expect(out.length, 1);
      expect(out.single.id, 'msg_1');
    });

    test('bản pending đến sau bản server cùng clientMessageId bị bỏ qua', () {
      final server = msg('msg_1', t1, cid: 'cid-1');
      final pending =
          msg('local-1', t0, cid: 'cid-1', status: SendStatus.pending);
      final out = mergeMessages([server], [pending]);
      expect(out.length, 1);
      expect(out.single.id, 'msg_1');
    });

    test('hai bản pending cùng clientMessageId không nhân đôi', () {
      final p1 = msg('local-1', t0, cid: 'cid-1', status: SendStatus.pending);
      final p2 = msg('local-2', t0, cid: 'cid-1', status: SendStatus.pending);
      final out = mergeMessages([p1], [p2]);
      expect(out.length, 1);
      expect(out.single.id, 'local-1');
    });

    test('server + server cùng id và cùng clientMessageId không nhân đôi', () {
      final out = mergeMessages(
        [msg('msg_1', t1, cid: 'cid-1')],
        [msg('msg_1', t1, cid: 'cid-1')],
      );
      expect(out.length, 1);
    });

    test('merge lặp lại (idempotent) với lịch sử REST + WebSocket', () {
      final rest = [msg('m1', t0, cid: 'c-1'), msg('m2', t1)];
      final ws = [msg('m2', t1), msg('m3', t2)];
      final once = mergeMessages(rest, ws);
      final twice = mergeMessages(once, ws);
      expect(once.map((m) => m.id).toList(), ['m1', 'm2', 'm3']);
      expect(twice.map((m) => m.id).toList(), ['m1', 'm2', 'm3']);
    });

    test('tin khác clientMessageId được giữ cả hai', () {
      final out = mergeMessages(
        [msg('local-1', t0, cid: 'a', status: SendStatus.pending)],
        [msg('msg_2', t1, cid: 'b')],
      );
      expect(out.length, 2);
    });
  });

  group('Outbox', () {
    test('tách theo user', () {
      final ob = Outbox();
      ob.add('u1', entry('a'));
      ob.add('u2', entry('b'));
      expect(ob.entriesFor('u1').map((e) => e.clientMessageId), ['a']);
      expect(ob.entriesFor('u2').map((e) => e.clientMessageId), ['b']);
      expect(ob.entriesFor('u3'), isEmpty);
      expect(ob.retryable('u1').map((e) => e.clientMessageId), ['a']);
      expect(ob.retryable('u3'), isEmpty);
    });

    test('entriesFor trả danh sách không sửa được', () {
      final ob = Outbox()..add('u1', entry('a'));
      expect(() => ob.entriesFor('u1').add(entry('x')),
          throwsUnsupportedError);
    });

    test('mặc định maxAttempts = 5', () {
      expect(Outbox().maxAttempts, 5);
    });

    test('markAttempt vượt maxAttempts => failed và không còn retryable', () {
      final ob = Outbox(maxAttempts: 3);
      ob.add('u1', entry('a'));
      ob.markAttempt('u1', 'a');
      ob.markAttempt('u1', 'a');
      expect(ob.entriesFor('u1').single.attempts, 2);
      expect(ob.entriesFor('u1').single.status, SendStatus.pending);
      expect(ob.retryable('u1'), hasLength(1));

      ob.markAttempt('u1', 'a');
      expect(ob.entriesFor('u1').single.attempts, 3);
      expect(ob.entriesFor('u1').single.status, SendStatus.failed);
      expect(ob.retryable('u1'), isEmpty);
    });

    test('markAttempt chỉ ảnh hưởng đúng user và đúng clientMessageId', () {
      final ob = Outbox(maxAttempts: 1);
      ob.add('u1', entry('a'));
      ob.add('u1', entry('b'));
      ob.add('u2', entry('a'));
      ob.markAttempt('u1', 'a');
      final u1 = {for (final e in ob.entriesFor('u1')) e.clientMessageId: e};
      expect(u1['a']!.status, SendStatus.failed);
      expect(u1['b']!.status, SendStatus.pending);
      expect(ob.entriesFor('u2').single.status, SendStatus.pending);
      expect(ob.entriesFor('u2').single.attempts, 0);
    });

    test('markAttempt với user hoặc id không tồn tại không lỗi', () {
      final ob = Outbox()..add('u1', entry('a'));
      ob.markAttempt('nobody', 'a');
      ob.markAttempt('u1', 'zzz');
      expect(ob.entriesFor('u1').single.attempts, 0);
    });

    test('markSent bỏ khỏi outbox', () {
      final ob = Outbox();
      ob.add('u1', entry('a'));
      ob.add('u1', entry('b'));
      ob.add('u2', entry('a'));
      ob.markSent('u1', 'a');
      expect(ob.entriesFor('u1').map((e) => e.clientMessageId), ['b']);
      expect(ob.entriesFor('u2'), hasLength(1));
      // user không tồn tại không lỗi
      ob.markSent('nobody', 'a');
    });

    test('failConversation chỉ đổi tin pending của hội thoại đó', () {
      final ob = Outbox();
      ob.add('u1', entry('a', conv: 'c1'));
      ob.add('u1', entry('b', conv: 'c2'));
      ob.add('u2', entry('c', conv: 'c1'));
      ob.failConversation('u1', 'c1');
      final u1 = {for (final e in ob.entriesFor('u1')) e.clientMessageId: e};
      expect(u1['a']!.status, SendStatus.failed);
      expect(u1['b']!.status, SendStatus.pending);
      expect(ob.entriesFor('u2').single.status, SendStatus.pending);
      expect(ob.retryable('u1').map((e) => e.clientMessageId), ['b']);
      // user không tồn tại không lỗi
      ob.failConversation('nobody', 'c1');
    });

    test('clearUser xóa toàn bộ outbox của user, không đụng user khác', () {
      final ob = Outbox();
      ob.add('u1', entry('a'));
      ob.add('u2', entry('b'));
      ob.clearUser('u1');
      expect(ob.entriesFor('u1'), isEmpty);
      expect(ob.retryable('u1'), isEmpty);
      expect(ob.entriesFor('u2'), hasLength(1));
      // thêm lại sau khi clear vẫn hoạt động
      ob.add('u1', entry('c'));
      expect(ob.entriesFor('u1'), hasLength(1));
    });

    test('OutboxEntry mặc định pending và attempts = 0', () {
      final e = entry('a');
      expect(e.status, SendStatus.pending);
      expect(e.attempts, 0);
    });
  });

  group('reconnectDelay', () {
    test('1, 2, 4, 8, 16 giây', () {
      expect(reconnectDelay(0), const Duration(seconds: 1));
      expect(reconnectDelay(1), const Duration(seconds: 2));
      expect(reconnectDelay(2), const Duration(seconds: 4));
      expect(reconnectDelay(3), const Duration(seconds: 8));
      expect(reconnectDelay(4), const Duration(seconds: 16));
    });

    test('chặn ở 30 giây từ lần thứ 5 trở đi', () {
      const cap = Duration(seconds: 30);
      expect(reconnectDelay(5), cap);
      expect(reconnectDelay(6), cap);
      expect(reconnectDelay(20), cap);
      expect(reconnectDelay(21), cap);
      expect(reconnectDelay(1000), cap);
    });

    test('attempt âm được coi như 0', () {
      expect(reconnectDelay(-1), const Duration(seconds: 1));
      expect(reconnectDelay(-100), const Duration(seconds: 1));
    });

    test('tham số base và max tùy chỉnh', () {
      expect(
        reconnectDelay(2,
            base: const Duration(milliseconds: 500),
            max: const Duration(seconds: 10)),
        const Duration(seconds: 2),
      );
      expect(
        reconnectDelay(10,
            base: const Duration(milliseconds: 500),
            max: const Duration(seconds: 10)),
        const Duration(seconds: 10),
      );
    });
  });

  group('messageForError', () {
    test('các mã REPORT_*', () {
      expect(messageForError(code: 'REPORT_ALREADY_PENDING'),
          kMsgAlreadyReported);
      expect(
          messageForError(code: 'REPORT_RATE_LIMITED'), kMsgReportRateLimited);
      expect(messageForError(code: 'REPORT_ALREADY_RESOLVED'),
          kMsgReportAlreadyResolved);
    });

    test('PRODUCT_NOT_AVAILABLE / PRODUCT_NOT_FOUND', () {
      expect(messageForError(code: 'PRODUCT_NOT_AVAILABLE'),
          kMsgProductUnavailable);
      expect(messageForError(code: 'PRODUCT_NOT_FOUND'), kMsgProductGone);
    });

    test('TOKEN_EXPIRED và ADMIN_REQUIRED', () {
      expect(messageForError(code: 'TOKEN_EXPIRED'), kMsgSessionExpired);
      expect(messageForError(code: 'ADMIN_REQUIRED'), kMsgForbidden);
    });

    test('mã được ưu tiên hơn httpStatus', () {
      expect(messageForError(code: 'REPORT_ALREADY_PENDING', httpStatus: 500),
          kMsgAlreadyReported);
      expect(messageForError(code: 'PRODUCT_NOT_AVAILABLE', httpStatus: 409),
          kMsgProductUnavailable);
    });

    test('mã lạ hoặc thiếu thì rơi về theo httpStatus', () {
      expect(messageForError(httpStatus: 401), kMsgSessionExpired);
      expect(messageForError(httpStatus: 403), kMsgForbidden);
      expect(messageForError(httpStatus: 404), kMsgProductGone);
      expect(messageForError(code: 'SOMETHING_NEW', httpStatus: 403),
          kMsgForbidden);
    });

    test('mặc định là thông báo generic', () {
      expect(messageForError(), kMsgGeneric);
      expect(messageForError(code: 'UNKNOWN'), kMsgGeneric);
      expect(messageForError(httpStatus: 500), kMsgGeneric);
      expect(messageForError(code: 'UNKNOWN', httpStatus: 422), kMsgGeneric);
    });
  });
}
