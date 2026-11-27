import 'package:test/test.dart';
import 'package:tv4_prep/tv4_prep.dart';

void main() {
  group('validateMessageText', () {
    test('null, rỗng, chỉ khoảng trắng => lỗi', () {
      expect(validateMessageText(null), isNotNull);
      expect(validateMessageText(''), isNotNull);
      expect(validateMessageText('   '), isNotNull);
      expect(validateMessageText(' \n\t '), isNotNull);
    });

    test('văn bản hợp lệ => null', () {
      expect(validateMessageText('Món này còn không bạn?'), isNull);
      expect(validateMessageText('  a  '), isNull);
    });

    test('đúng 1000 ký tự hợp lệ, 1001 ký tự bị từ chối', () {
      expect(validateMessageText('a' * 1000), isNull);
      final err = validateMessageText('a' * 1001);
      expect(err, isNotNull);
      expect(err, contains('1000'));
    });

    test('giới hạn tính sau khi trim', () {
      expect(validateMessageText('  ${'a' * 1000}  '), isNull);
      expect(validateMessageText('${'a' * 1000} b'), isNotNull);
    });
  });

  group('validateReport', () {
    test('không chọn lý do => lỗi', () {
      expect(validateReport(reason: null), isNotNull);
      expect(validateReport(reason: null, description: 'abc'), isNotNull);
    });

    test('lý do thường, không mô tả => hợp lệ', () {
      expect(validateReport(reason: ReportReason.scam), isNull);
      expect(validateReport(reason: ReportReason.spam, description: ''), isNull);
    });

    test('OTHER cần tối thiểu 10 ký tự sau trim', () {
      expect(validateReport(reason: ReportReason.other), isNotNull);
      expect(validateReport(reason: ReportReason.other, description: ''),
          isNotNull);
      expect(
          validateReport(reason: ReportReason.other, description: 'a' * 9),
          isNotNull);
      expect(
          validateReport(reason: ReportReason.other, description: 'a' * 10),
          isNull);
      // khoảng trắng không được tính
      expect(
          validateReport(
              reason: ReportReason.other, description: '   ${'a' * 9}   '),
          isNotNull);
    });

    test('mô tả 500 hợp lệ, 501 bị từ chối', () {
      expect(
          validateReport(reason: ReportReason.fake, description: 'a' * 500),
          isNull);
      final err =
          validateReport(reason: ReportReason.fake, description: 'a' * 501);
      expect(err, isNotNull);
      expect(err, contains('500'));
    });

    test('OTHER với mô tả 501 ký tự cũng bị từ chối', () {
      expect(
          validateReport(reason: ReportReason.other, description: 'a' * 501),
          isNotNull);
    });

    test('lý do không phải OTHER, mô tả ngắn vẫn hợp lệ', () {
      expect(
          validateReport(reason: ReportReason.misleading, description: 'x'),
          isNull);
    });
  });

  group('validateAdminNote', () {
    test('null, rỗng, chỉ khoảng trắng, dưới 5 ký tự => lỗi', () {
      expect(validateAdminNote(null), isNotNull);
      expect(validateAdminNote(''), isNotNull);
      expect(validateAdminNote('     '), isNotNull);
      expect(validateAdminNote('abcd'), isNotNull);
      expect(validateAdminNote('  abcd  '), isNotNull);
    });

    test('từ 5 ký tự trở lên => hợp lệ', () {
      expect(validateAdminNote('abcde'), isNull);
      expect(validateAdminNote('  abcde  '), isNull);
      expect(validateAdminNote('Product có dấu hiệu lừa đảo'), isNull);
    });
  });
}
