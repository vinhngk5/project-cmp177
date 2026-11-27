import 'dart:convert';

import 'package:test/test.dart';
import 'package:tv4_prep/tv4_prep.dart';

void main() {
  group('ApiException', () {
    test('message tiếng Việt lấy từ messageForError, bỏ qua message của server',
        () {
      final e = ApiException.fromEnvelope(409, {
        'error': {
          'code': 'REPORT_ALREADY_PENDING',
          'message': 'Report already pending (traceback...)',
          'details': [],
        },
        'meta': {'request_id': 'req_01JREQUEST'},
      });

      expect(e.httpStatus, 409);
      expect(e.code, 'REPORT_ALREADY_PENDING');
      expect(e.message, kMsgAlreadyReported);
      expect(e.requestId, 'req_01JREQUEST');
      expect(e.isConflict, isTrue);
    });

    test('mã DUPLICATE_PENDING_REPORT (API.md mục 5) được chuẩn hóa', () {
      final e = ApiException(httpStatus: 409, code: 'DUPLICATE_PENDING_REPORT');

      expect(e.code, 'REPORT_ALREADY_PENDING');
      expect(e.message, kMsgAlreadyReported);
    });

    test('fallback theo HTTP status khi mã lạ hoặc thiếu', () {
      expect(ApiException(httpStatus: 403, code: 'WHATEVER').message, kMsgForbidden);
      expect(ApiException(httpStatus: 401).message, kMsgSessionExpired);
      expect(ApiException(httpStatus: 500).message, kMsgGeneric);
      expect(ApiException(httpStatus: 503, code: 'X').isServerError, isTrue);
    });

    test('body sai định dạng vẫn tạo được exception hợp lệ', () {
      for (final body in <Object?>[null, 'oops', 42, <String, Object?>{}, {'error': 'x'}]) {
        final e = ApiException.fromEnvelope(500, body);
        expect(e.httpStatus, 500);
        expect(e.code, isNull);
        expect(e.message, kMsgGeneric);
      }
    });

    test('fromResponse: decode JSON và đọc Retry-After', () {
      final raw = jsonEncode({
        'error': {'code': 'REPORT_RATE_LIMITED', 'message': 'Too many'},
        'meta': {'request_id': 'req_1'},
      });

      final e = ApiException.fromResponse(429, raw, retryAfterHeader: ' 120 ');

      expect(e.isRateLimited, isTrue);
      expect(e.code, 'REPORT_RATE_LIMITED');
      expect(e.message, kMsgReportRateLimited);
      expect(e.retryAfter, const Duration(seconds: 120));
    });

    test('fromResponse: body không phải JSON / rỗng / header lạ', () {
      final html = ApiException.fromResponse(
        502,
        '<html>Bad Gateway</html>',
        retryAfterHeader: 'Wed, 21 Oct 2026 07:28:00 GMT',
      );
      expect(html.httpStatus, 502);
      expect(html.code, isNull);
      expect(html.retryAfter, isNull);
      expect(html.message, kMsgGeneric);

      expect(ApiException.fromResponse(404, null).message, kMsgProductGone);
      expect(ApiException.fromResponse(404, '  ').httpStatus, 404);
    });

    test('lỗi mạng', () {
      final e = ApiException.network();

      expect(e.isNetwork, isTrue);
      expect(e.httpStatus, kHttpStatusNetwork);
      expect(e.message, kMsgOffline);
    });

    test('errorMessageOf không lộ lỗi lạ', () {
      expect(errorMessageOf(ApiException.network()), kMsgOffline);
      expect(errorMessageOf(StateError('SELECT * FROM users')), kMsgGeneric);
    });
  });

  group('PageResult.fromMeta', () {
    test('page/page_size: suy ra hasMore từ total_items', () {
      final p = PageResult<int>.fromMeta(
        [1, 2],
        {'page': 1, 'page_size': 2, 'total_items': 5},
      );
      expect(p.hasMore, isTrue);
      expect(p.totalItems, 5);

      final last = PageResult<int>.fromMeta(
        [5],
        {'page': 3, 'page_size': 2, 'total_items': 5},
      );
      expect(last.hasMore, isFalse);
    });

    test('cursor: dùng has_more và next_cursor của server', () {
      final p = PageResult<int>.fromMeta(
        [1],
        {'next_cursor': 'msg_9', 'has_more': true},
      );
      expect(p.hasMore, isTrue);
      expect(p.nextCursor, 'msg_9');

      final end = PageResult<int>.fromMeta(
        [1],
        {'next_cursor': null, 'has_more': false},
      );
      expect(end.hasMore, isFalse);
      expect(end.nextCursor, isNull);
    });

    test('meta rỗng hoặc null', () {
      expect(PageResult<int>.fromMeta([1, 2], null).hasMore, isFalse);
      expect(PageResult<int>.fromMeta([1, 2], {}).totalItems, 2);
    });
  });

  group('parseChatSocketEvent (JSON mẫu API.md mục 4.6)', () {
    test('message.ack', () {
      final e = parseChatSocketEvent({
        'event': 'message.ack',
        'data': {
          'client_message_id': 'local-uuid-123',
          'message_id': 'msg_01JMESSAGE1',
          'status': 'SENT',
          'created_at': '2026-11-27T04:01:00Z',
        },
      });

      expect(e, isA<MessageAck>());
      final ack = e as MessageAck;
      expect(ack.clientMessageId, 'local-uuid-123');
      expect(ack.messageId, 'msg_01JMESSAGE1');
      expect(ack.createdAt, DateTime.utc(2026, 11, 27, 4, 1));
    });

    test('message.new: conversation_id nằm ngoài message', () {
      final e = parseChatSocketEvent({
        'event': 'message.new',
        'data': {
          'conversation_id': 'cnv_01JCONV1',
          'message': {
            'id': 'msg_01JMESSAGE1',
            'sender_id': 'usr_01JBUYER1',
            'type': 'TEXT',
            'text': 'Mon nay con khong ban?',
            'created_at': '2026-11-27T04:01:00Z',
          },
        },
      });

      final created = e as MessageNew;
      expect(created.conversationId, 'cnv_01JCONV1');
      expect(created.message.conversationId, 'cnv_01JCONV1');
      expect(created.message.text, 'Mon nay con khong ban?');
    });

    test('error: thiếu retryable thì coi là retry được', () {
      final e = parseChatSocketEvent({
        'event': 'error',
        'data': {'code': 'CONVERSATION_READ_ONLY', 'message': 'x'},
      });

      final err = e as SocketError;
      expect(err.code, 'CONVERSATION_READ_ONLY');
      expect(err.retryable, isTrue);
    });

    test('frame lạ hoặc hỏng: trả null, không ném', () {
      expect(parseChatSocketEvent(null), isNull);
      expect(parseChatSocketEvent('x'), isNull);
      expect(parseChatSocketEvent({'event': 'ping', 'data': {}}), isNull);
      expect(parseChatSocketEvent({'event': 'message.ack', 'data': {}}), isNull);
      expect(parseChatSocketEvent({'event': 'message.new'}), isNull);
    });
  });

  group('model nhỏ', () {
    test('ConversationRef, ReadReceipt, ResolveResult, BanResult.fromJson', () {
      final conv = ConversationRef.fromJson({
        'id': 'cnv_01JCONV1',
        'product_id': 'prd_01JPRODUCT1',
        'buyer_id': 'usr_01JBUYER1',
        'seller_id': 'usr_01JABC123',
        'created_at': '2026-11-27T04:00:00Z',
        'is_new': true,
      });
      expect(conv.isNew, isTrue);
      expect(conv.sellerId, 'usr_01JABC123');

      final receipt = ReadReceipt.fromJson({
        'conversation_id': 'cnv_01JCONV1',
        'unread_count': 0,
        'last_read_at': '2026-11-27T04:31:00Z',
      });
      expect(receipt.unreadCount, 0);

      final resolved = ResolveResult.fromJson({
        'report_id': 'rpt_01JREPORT1',
        'report_status': 'RESOLVED',
        'action': 'REMOVE_PRODUCT_AND_BAN_OWNER',
        'product_status': 'BLOCKED',
        'owner_status': 'BANNED',
        'resolved_at': '2026-11-27T07:00:00Z',
      });
      expect(resolved.reportStatus, ReportStatus.resolved);
      expect(resolved.action, AdminAction.removeProductAndBanOwner);
      expect(resolved.ownerStatus, 'BANNED');

      final ban = BanResult.fromJson({
        'user_id': 'usr_01JABC123',
        'status': 'BANNED',
        'ban_reason': 'Tai khoan co hanh vi vi pham lap lai.',
        'banned_at': '2026-11-27T07:05:00Z',
      });
      expect(ban.status, 'BANNED');
      expect(adminActionFromCode('NOPE'), isNull);
    });
  });
}
