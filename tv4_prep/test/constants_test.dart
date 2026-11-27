import 'package:test/test.dart';
import 'package:tv4_prep/tv4_prep.dart';

void main() {
  group('Giới hạn validate', () {
    test('giá trị theo SRS/API', () {
      expect(kMessageMaxLength, 1000);
      expect(kHistoryDefaultLimit, 30);
      expect(kHistoryMaxLimit, 100);
      expect(kReportDescriptionMaxLength, 500);
      expect(kReportOtherMinLength, 10);
      expect(kAdminNoteMinLength, 5);
      expect(kReportDailyLimit, 10);
    });
  });

  group('Quick reply (Phụ lục B)', () {
    test('buyer 5 câu, seller 5 câu', () {
      expect(kBuyerQuickReplies.length, 5);
      expect(kSellerQuickReplies.length, 5);
    });

    test('không rỗng, không trùng, nằm trong giới hạn tin nhắn', () {
      for (final list in [kBuyerQuickReplies, kSellerQuickReplies]) {
        expect(list.toSet().length, list.length);
        for (final s in list) {
          expect(s.trim(), isNotEmpty);
          expect(validateMessageText(s), isNull);
        }
      }
    });
  });

  group('Safety tips (Phụ lục F)', () {
    test('có 6 mẹo, không rỗng, không trùng', () {
      expect(kSafetyTips.length, 6);
      expect(kSafetyTips.toSet().length, 6);
      for (final s in kSafetyTips) {
        expect(s.trim(), isNotEmpty);
      }
    });
  });

  group('ReportReason (Phụ lục C)', () {
    test('đủ 8 mã đúng thứ tự', () {
      expect(ReportReason.values.length, 8);
      expect(ReportReason.values.map((e) => e.code).toList(), [
        'PROHIBITED',
        'SCAM',
        'FAKE',
        'MISLEADING',
        'INAPPROPRIATE',
        'WRONG_CATEGORY',
        'SPAM',
        'OTHER',
      ]);
    });

    test('mỗi mã có nhãn không rỗng và fromCode khớp ngược', () {
      for (final r in ReportReason.values) {
        expect(r.label.trim(), isNotEmpty);
        expect(ReportReason.fromCode(r.code), r);
      }
    });

    test('mã là duy nhất', () {
      final codes = ReportReason.values.map((e) => e.code).toSet();
      expect(codes.length, 8);
    });
  });

  group('Thông báo chuẩn', () {
    test('không rỗng', () {
      for (final s in [
        kMsgOffline,
        kMsgForbidden,
        kMsgProductGone,
        kMsgAlreadyReported,
        kMsgReportThanks,
        kMsgGeneric,
        kMsgSessionExpired,
        kMsgProductUnavailable,
        kMsgReportRateLimited,
        kMsgReportAlreadyResolved,
        kMsgChatReadOnly,
      ]) {
        expect(s.trim(), isNotEmpty);
      }
    });
  });
}
