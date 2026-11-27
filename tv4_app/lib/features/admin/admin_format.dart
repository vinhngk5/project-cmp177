/// Hàm định dạng và nhãn dùng riêng cho khu vực Admin.
library;

import 'package:material_ui/material_ui.dart';
import 'package:tv4_prep/tv4_prep.dart';

import '../../core/theme.dart';

/// Độ dài tối đa của ghi chú xử lý (khớp bộ đếm 0/500 trong Figma).
const int kAdminNoteMaxLength = 500;

/// Nhãn nút theo Figma (dùng "khoá"); `AdminAction.label` trong tv4_prep viết "khóa".
String adminActionLabel(AdminAction action) => switch (action) {
      AdminAction.rejectReport => 'Không vi phạm',
      AdminAction.removeProduct => 'Gỡ tin',
      AdminAction.removeProductAndBanOwner => 'Gỡ tin + khoá chủ tin',
    };

String reasonLabel(ReportReason? reason) =>
    reason?.label ?? 'Lý do khác / không xác định';

/// 45000 -> "45.000 ₫".
String formatVnd(int value) {
  final digits = value.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  return '${value < 0 ? '-' : ''}$buf ₫';
}

String _two(int n) => n.toString().padLeft(2, '0');

/// "Hôm nay 09:40", "Hôm qua 08:10" hoặc "27/11 08:10" (giờ địa phương).
String formatWhen(DateTime time, {DateTime? now}) {
  final t = time.toLocal();
  final n = (now ?? DateTime.now()).toLocal();
  final hm = '${_two(t.hour)}:${_two(t.minute)}';
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Hôm nay $hm';
  if (diff == 1) return 'Hôm qua $hm';
  return '${_two(t.day)}/${_two(t.month)} $hm';
}

/// Trạng thái hiện tại của tin (target.status) -> (nhãn, nền, chữ).
(String, Color, Color) productStatusStyle(String code) => switch (code) {
      'AVAILABLE' => ('Đang đăng bán', AppColors.successSoft, AppColors.success),
      'SOLD' => ('Đã bán', AppColors.primarySoft, AppColors.primary),
      'HIDDEN' => ('Đang ẩn', AppColors.warningSoft, AppColors.warning),
      'BLOCKED' => ('Đã bị gỡ', AppColors.dangerSoft, AppColors.danger),
      'DELETED' => ('Đã xoá', AppColors.dangerSoft, AppColors.danger),
      _ => ('Không rõ', AppColors.bubbleOther, AppColors.muted),
    };

/// Trạng thái của báo cáo -> (nhãn, nền, chữ).
(String, Color, Color) reportStatusStyle(ReportStatus status) =>
    switch (status) {
      ReportStatus.pending =>
        ('Chờ xử lý', AppColors.warningSoft, AppColors.warning),
      ReportStatus.resolved =>
        ('Đã xử lý', AppColors.successSoft, AppColors.success),
      ReportStatus.rejected =>
        ('Không vi phạm', AppColors.primarySoft, AppColors.primary),
      ReportStatus.unknown =>
        ('Không rõ', AppColors.bubbleOther, AppColors.muted),
    };
