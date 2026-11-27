/// Widget nhỏ dùng chung trong khu vực Báo cáo.
library;

import 'package:material_ui/material_ui.dart';
import 'package:tv4_prep/tv4_prep.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'report_format.dart';

/// Đang chờ xử lý = warning, Đã xử lý = success, Không vi phạm = muted.
class ReportStatusBadge extends StatelessWidget {
  const ReportStatusBadge({super.key, required this.status});

  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      ReportStatus.pending => (AppColors.warningSoft, AppColors.warning),
      ReportStatus.resolved => (AppColors.successSoft, AppColors.success),
      ReportStatus.rejected ||
      ReportStatus.unknown =>
        (AppColors.bubbleOther, AppColors.muted),
    };
    return StatusBadge(
      label: reportStatusLabel(status),
      background: bg,
      foreground: fg,
    );
  }
}
