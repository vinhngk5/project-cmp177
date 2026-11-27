/// Định dạng giờ / tiền cho khu vực Chat (không dùng gói intl để khỏi thêm phụ thuộc).
library;

import 'package:tv4_prep/tv4_prep.dart';

String _two(int n) => n.toString().padLeft(2, '0');

/// HH:mm theo giờ máy.
String formatClock(DateTime t) {
  final l = t.toLocal();
  return '${_two(l.hour)}:${_two(l.minute)}';
}

/// Giờ ở cột phải của danh sách: hôm nay -> HH:mm, hôm qua -> "Hôm qua",
/// cũ hơn -> dd/MM (thêm năm nếu khác năm hiện tại).
String formatListTime(DateTime t, {required DateTime now}) {
  final l = t.toLocal();
  final day = DateTime(l.year, l.month, l.day);
  final label = formatDividerLabel(day, now: now);
  if (label == 'Hôm nay') return formatClock(t);
  if (label == 'Hôm qua') return label;
  final dm = '${_two(l.day)}/${_two(l.month)}';
  return l.year == now.year ? dm : '$dm/${l.year}';
}

/// 45000 -> "45.000 đ".
String formatVnd(int amount) {
  final digits = amount.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  return '${amount < 0 ? '-' : ''}$buf đ';
}
