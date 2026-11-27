/// Hàm định dạng hiển thị cho màn Báo cáo (không phụ thuộc Flutter).
library;

import 'package:tv4_prep/tv4_prep.dart';

/// 45000 -> "45.000 ₫".
String formatVnd(int amount) {
  final negative = amount < 0;
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}$buffer ₫';
}

String _two(int n) => n.toString().padLeft(2, '0');

/// "27/11/2026, 13:00" theo giờ local.
String formatDateTimeFull(DateTime t) {
  final l = t.toLocal();
  return '${_two(l.day)}/${_two(l.month)}/${l.year}, ${_two(l.hour)}:${_two(l.minute)}';
}

/// "27/11, 13:00"; thêm năm nếu khác năm của [now].
String formatDateTimeShort(DateTime t, {required DateTime now}) {
  final l = t.toLocal();
  if (l.year != now.toLocal().year) return formatDateTimeFull(t);
  return '${_two(l.day)}/${_two(l.month)}, ${_two(l.hour)}:${_two(l.minute)}';
}

String reportStatusLabel(ReportStatus status) => switch (status) {
      ReportStatus.pending => 'Đang chờ xử lý',
      ReportStatus.resolved => 'Đã xử lý',
      ReportStatus.rejected => 'Không vi phạm',
      ReportStatus.unknown => 'Không xác định',
    };

/// Lý do hiển thị; mã lạ (null) -> "Khác".
String reportReasonLabel(ReportReason? reason) => reason?.label ?? 'Khác';

/// Tiêu đề snapshot của tin; thiếu thì dùng nhãn chung.
String reportTitleOf(MyReport r) {
  final t = r.productTitleSnapshot?.trim();
  return (t == null || t.isEmpty) ? 'Tin đăng' : t;
}
