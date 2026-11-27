import 'package:test/test.dart';
import 'package:tv4_prep/tv4_prep.dart';

void main() {
  group('Message.fromJson', () {
    test('parse mẫu API-CHAT-03', () {
      final m = Message.fromJson({
        'id': 'msg_01JMESSAGE1',
        'conversation_id': 'cnv_01JCONV1',
        'sender_id': 'usr_01JBUYER1',
        'type': 'TEXT',
        'text': 'Mon nay con khong ban?',
        'client_message_id': 'local-uuid-123',
        'created_at': '2026-11-27T04:01:00Z',
        'read_at': null,
      });
      expect(m.id, 'msg_01JMESSAGE1');
      expect(m.conversationId, 'cnv_01JCONV1');
      expect(m.senderId, 'usr_01JBUYER1');
      expect(m.type, MessageType.text);
      expect(m.text, 'Mon nay con khong ban?');
      expect(m.clientMessageId, 'local-uuid-123');
      expect(m.createdAt, DateTime.utc(2026, 11, 27, 4, 1));
      expect(m.createdAt.isUtc, isTrue);
      expect(m.readAt, isNull);
      expect(m.sendStatus, SendStatus.sent);
    });

    test('read_at có giá trị được parse', () {
      final m = Message.fromJson({
        'id': 'm1',
        'conversation_id': 'c1',
        'sender_id': 'u1',
        'type': 'TEXT',
        'text': 'x',
        'created_at': '2026-11-27T04:01:00Z',
        'read_at': '2026-11-27T04:05:00Z',
      });
      expect(m.readAt, DateTime.utc(2026, 11, 27, 4, 5));
      expect(m.clientMessageId, isNull);
    });

    test('type SYSTEM', () {
      final m = Message.fromJson({
        'id': 'm1',
        'conversation_id': 'c1',
        'sender_id': 'u1',
        'type': 'SYSTEM',
        'text': 'Cuộc trò chuyện đã đóng',
        'created_at': '2026-11-27T04:01:00Z',
      });
      expect(m.type, MessageType.system);
    });

    test('mã type lạ hoặc thiếu không crash, trả về unknown', () {
      final base = {
        'id': 'm1',
        'conversation_id': 'c1',
        'sender_id': 'u1',
        'text': 'x',
        'created_at': '2026-11-27T04:01:00Z',
      };
      expect(Message.fromJson({...base, 'type': 'IMAGE'}).type,
          MessageType.unknown);
      expect(Message.fromJson({...base, 'type': null}).type,
          MessageType.unknown);
      expect(Message.fromJson(base).type, MessageType.unknown);
    });

    test('text null thành chuỗi rỗng', () {
      final m = Message.fromJson({
        'id': 'm1',
        'conversation_id': 'c1',
        'sender_id': 'u1',
        'type': 'TEXT',
        'text': null,
        'created_at': '2026-11-27T04:01:00Z',
      });
      expect(m.text, '');
    });

    test('copyWith đổi id, sendStatus, createdAt và giữ phần còn lại', () {
      final m = Message(
        id: 'local-1',
        conversationId: 'c1',
        senderId: 'u1',
        type: MessageType.text,
        text: 'hi',
        createdAt: DateTime.utc(2026, 11, 27, 1),
        clientMessageId: 'cid',
        sendStatus: SendStatus.pending,
      );
      final c = m.copyWith(
        id: 'msg_1',
        sendStatus: SendStatus.sent,
        createdAt: DateTime.utc(2026, 11, 27, 2),
      );
      expect(c.id, 'msg_1');
      expect(c.sendStatus, SendStatus.sent);
      expect(c.createdAt, DateTime.utc(2026, 11, 27, 2));
      expect(c.clientMessageId, 'cid');
      expect(c.text, 'hi');
      expect(c.conversationId, 'c1');
      // bản gốc không đổi
      expect(m.id, 'local-1');
      expect(m.sendStatus, SendStatus.pending);
    });
  });

  group('ConversationSummary.fromJson', () {
    final sample = <String, dynamic>{
      'id': 'cnv_01JCONV1',
      'product_id': 'prd_01JPRODUCT1',
      'product_title': 'Giao trinh Giai tich 1',
      'other_participant': {
        'id': 'usr_01JABC123',
        'display_name': 'Nguyen Van A'
      },
      'last_message': {
        'text': 'Minh hen 5h nhe',
        'created_at': '2026-11-27T04:30:00Z'
      },
      'unread_count': 2,
    };

    test('mẫu API 6.6 có last_message, thiếu status => open', () {
      final c = ConversationSummary.fromJson(sample);
      expect(c.id, 'cnv_01JCONV1');
      expect(c.productId, 'prd_01JPRODUCT1');
      expect(c.productTitle, 'Giao trinh Giai tich 1');
      expect(c.other.id, 'usr_01JABC123');
      expect(c.other.displayName, 'Nguyen Van A');
      expect(c.lastMessage, isNotNull);
      expect(c.lastMessage!.text, 'Minh hen 5h nhe');
      expect(c.lastMessage!.createdAt, DateTime.utc(2026, 11, 27, 4, 30));
      expect(c.unreadCount, 2);
      expect(c.status, ConversationStatus.open);
      expect(c.isReadOnly, isFalse);
    });

    test('last_message null => lastMessage null', () {
      final c = ConversationSummary.fromJson({...sample, 'last_message': null});
      expect(c.lastMessage, isNull);
    });

    test('không có khóa last_message => lastMessage null', () {
      final j = Map<String, dynamic>.from(sample)..remove('last_message');
      expect(ConversationSummary.fromJson(j).lastMessage, isNull);
    });

    test('status READ_ONLY => isReadOnly', () {
      final c = ConversationSummary.fromJson({...sample, 'status': 'READ_ONLY'});
      expect(c.status, ConversationStatus.readOnly);
      expect(c.isReadOnly, isTrue);
    });

    test('status lạ => open, không crash', () {
      final c = ConversationSummary.fromJson({...sample, 'status': 'ARCHIVED'});
      expect(c.status, ConversationStatus.open);
    });

    test('unread_count thiếu => 0, product_title thiếu => rỗng', () {
      final j = Map<String, dynamic>.from(sample)
        ..remove('unread_count')
        ..remove('product_title');
      final c = ConversationSummary.fromJson(j);
      expect(c.unreadCount, 0);
      expect(c.productTitle, '');
    });
  });

  group('MyReport.fromJson', () {
    test('mẫu API-REPORT-02 (có snapshot title, resolved_at null)', () {
      final r = MyReport.fromJson({
        'id': 'rpt_01JREPORT1',
        'product_id': 'prd_01JPRODUCT1',
        'product_title_snapshot': 'Giao trinh Giai tich 1',
        'reason': 'MISLEADING',
        'status': 'PENDING',
        'created_at': '2026-11-27T06:00:00Z',
        'resolved_at': null,
      });
      expect(r.id, 'rpt_01JREPORT1');
      expect(r.productId, 'prd_01JPRODUCT1');
      expect(r.productTitleSnapshot, 'Giao trinh Giai tich 1');
      expect(r.reason, ReportReason.misleading);
      expect(r.status, ReportStatus.pending);
      expect(r.createdAt, DateTime.utc(2026, 11, 27, 6));
      expect(r.resolvedAt, isNull);
      expect(r.description, isNull);
      expect(r.resolutionNote, isNull);
    });

    test('mẫu chi tiết 6.8 (không có product_title_snapshot)', () {
      final r = MyReport.fromJson({
        'id': 'rpt_01JREPORT1',
        'product_id': 'prd_01JPRODUCT1',
        'reason': 'MISLEADING',
        'description': 'Anh va mo ta khong trung khop.',
        'status': 'PENDING',
        'created_at': '2026-11-27T06:00:00Z',
        'resolution_note': null,
      });
      expect(r.productTitleSnapshot, isNull);
      expect(r.description, 'Anh va mo ta khong trung khop.');
      expect(r.resolutionNote, isNull);
    });

    test('report đã xử lý có resolution_note và resolved_at', () {
      final r = MyReport.fromJson({
        'id': 'r1',
        'product_id': 'p1',
        'reason': 'SCAM',
        'status': 'RESOLVED',
        'created_at': '2026-11-27T06:00:00Z',
        'resolved_at': '2026-11-28T01:00:00Z',
        'resolution_note': 'Đã gỡ tin.',
      });
      expect(r.status, ReportStatus.resolved);
      expect(r.resolvedAt, DateTime.utc(2026, 11, 28, 1));
      expect(r.resolutionNote, 'Đã gỡ tin.');
    });

    test('reason lạ => null, status lạ => unknown, không crash', () {
      final r = MyReport.fromJson({
        'id': 'r1',
        'product_id': 'p1',
        'reason': 'NEW_REASON',
        'status': 'ESCALATED',
        'created_at': '2026-11-27T06:00:00Z',
      });
      expect(r.reason, isNull);
      expect(r.status, ReportStatus.unknown);
    });
  });

  group('AdminReportItem.fromJson', () {
    test('mẫu API 6.9', () {
      final i = AdminReportItem.fromJson({
        'id': 'rpt_01JREPORT1',
        'target_type': 'PRODUCT',
        'target_id': 'prd_01JPRODUCT1',
        'reason': 'MISLEADING',
        'status': 'PENDING',
        'created_at': '2026-11-27T06:00:00Z',
      });
      expect(i.id, 'rpt_01JREPORT1');
      expect(i.targetType, 'PRODUCT');
      expect(i.targetId, 'prd_01JPRODUCT1');
      expect(i.reason, ReportReason.misleading);
      expect(i.status, ReportStatus.pending);
      expect(i.createdAt, DateTime.utc(2026, 11, 27, 6));
    });

    test('mã lạ không crash', () {
      final i = AdminReportItem.fromJson({
        'id': 'r',
        'target_type': 'USER',
        'target_id': 'u',
        'reason': 'XYZ',
        'status': 'XYZ',
        'created_at': '2026-11-27T06:00:00Z',
      });
      expect(i.reason, isNull);
      expect(i.status, ReportStatus.unknown);
    });
  });

  group('AdminReportDetail', () {
    Map<String, dynamic> sample({String status = 'PENDING'}) => {
          'id': 'rpt_01JREPORT1',
          'reporter': {
            'display_name': 'Nguyen B',
            'joined_at': '2026-10-01T00:00:00Z'
          },
          'target': {
            'type': 'PRODUCT',
            'id': 'prd_01JPRODUCT1',
            'status': 'AVAILABLE'
          },
          'snapshot': {
            'title': 'Giao trinh Giai tich 1',
            'price_vnd': 45000,
            'cover_image_url': null
          },
          'reason': 'MISLEADING',
          'description': 'Thong tin khong trung khop.',
          'status': status,
        };

    test('fromJson mẫu API 6.9', () {
      final d = AdminReportDetail.fromJson(sample());
      expect(d.id, 'rpt_01JREPORT1');
      expect(d.reporterName, 'Nguyen B');
      expect(d.targetId, 'prd_01JPRODUCT1');
      expect(d.targetStatus, 'AVAILABLE');
      expect(d.snapshotTitle, 'Giao trinh Giai tich 1');
      expect(d.snapshotPriceVnd, 45000);
      expect(d.snapshotCoverImageUrl, isNull);
      expect(d.reason, ReportReason.misleading);
      expect(d.description, 'Thong tin khong trung khop.');
      expect(d.status, ReportStatus.pending);
    });

    test('cover_image_url có giá trị', () {
      final j = sample();
      (j['snapshot'] as Map<String, dynamic>)['cover_image_url'] =
          'https://cdn.example/x.jpg';
      expect(AdminReportDetail.fromJson(j).snapshotCoverImageUrl,
          'https://cdn.example/x.jpg');
    });

    test('canResolve chỉ true khi PENDING', () {
      expect(AdminReportDetail.fromJson(sample()).canResolve, isTrue);
      expect(
          AdminReportDetail.fromJson(sample(status: 'RESOLVED')).canResolve,
          isFalse);
      expect(
          AdminReportDetail.fromJson(sample(status: 'REJECTED')).canResolve,
          isFalse);
      expect(AdminReportDetail.fromJson(sample(status: 'WHATEVER')).canResolve,
          isFalse);
    });

    test('reason lạ không crash', () {
      final j = sample()..['reason'] = 'NEW';
      expect(AdminReportDetail.fromJson(j).reason, isNull);
    });
  });

  group('Enum.fromCode', () {
    test('MessageType / ConversationStatus / ReportStatus', () {
      expect(MessageType.fromCode('TEXT'), MessageType.text);
      expect(MessageType.fromCode(null), MessageType.unknown);
      expect(ConversationStatus.fromCode(null), ConversationStatus.open);
      expect(ConversationStatus.fromCode('READ_ONLY'),
          ConversationStatus.readOnly);
      expect(ReportStatus.fromCode('REJECTED'), ReportStatus.rejected);
      expect(ReportStatus.fromCode(null), ReportStatus.unknown);
    });

    test('ReportReason.fromCode: mã hợp lệ, lạ, null, chữ thường', () {
      expect(ReportReason.fromCode('SCAM'), ReportReason.scam);
      expect(ReportReason.fromCode('WRONG_CATEGORY'),
          ReportReason.wrongCategory);
      expect(ReportReason.fromCode('nope'), isNull);
      expect(ReportReason.fromCode(null), isNull);
      expect(ReportReason.fromCode('scam'), isNull);
    });

    test('AdminAction có đủ 3 mã theo API-ADMIN-03', () {
      expect(AdminAction.values.map((e) => e.code).toList(), [
        'REJECT_REPORT',
        'REMOVE_PRODUCT',
        'REMOVE_PRODUCT_AND_BAN_OWNER',
      ]);
    });
  });
}
