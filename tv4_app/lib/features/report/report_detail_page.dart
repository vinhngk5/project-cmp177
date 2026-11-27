import 'package:material_ui/material_ui.dart';
import 'package:tv4_prep/tv4_prep.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'report_format.dart';
import 'report_widgets.dart';

/// Màn "Chi tiết báo cáo". Nhận [MyReport] đã có từ danh sách.
class ReportDetailPage extends StatelessWidget {
  const ReportDetailPage({super.key, required this.report});

  final MyReport report;

  @override
  Widget build(BuildContext context) {
    final description = report.description?.trim();
    final note = report.resolutionNote?.trim();
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết báo cáo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        reportTitleOf(report),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ReportStatusBadge(status: report.status),
                  ],
                ),
                _Field(label: 'Lý do', value: reportReasonLabel(report.reason)),
                if (description != null && description.isNotEmpty)
                  _Field(label: 'Mô tả của bạn', value: description),
                _Field(
                  label: 'Gửi lúc',
                  value: formatDateTimeFull(report.createdAt),
                ),
                if (report.resolvedAt != null)
                  _Field(
                    label: 'Xử lý lúc',
                    value: formatDateTimeFull(report.resolvedAt!),
                  ),
                if (note != null && note.isNotEmpty)
                  _Field(label: 'Kết quả xử lý', value: note),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

/// Dùng khi mở route chi tiết mà thiếu arguments hợp lệ.
class ReportDetailMissing extends StatelessWidget {
  const ReportDetailMissing({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết báo cáo')),
      body: const ErrorState(message: 'Không tìm thấy báo cáo.'),
    );
  }
}
