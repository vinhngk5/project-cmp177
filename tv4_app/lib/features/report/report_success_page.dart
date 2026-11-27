import 'package:material_ui/material_ui.dart';
import 'package:tv4_prep/tv4_prep.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'report_routes.dart';

/// Màn "Đã gửi báo cáo" (MSG-08).
class ReportSuccessPage extends StatelessWidget {
  const ReportSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo cáo tin đăng'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          const Expanded(
            child: EmptyState(
              icon: Icons.check,
              iconColor: AppColors.success,
              iconBackground: AppColors.successSoft,
              title: 'Đã gửi báo cáo',
              message: kMsgReportThanks,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  AppButton(
                    label: 'Xem báo cáo của tôi',
                    onPressed: () =>
                        navigator.pushReplacementNamed(kMyReportsRoute),
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Xong',
                    kind: AppButtonKind.secondary,
                    onPressed: navigator.pop,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
