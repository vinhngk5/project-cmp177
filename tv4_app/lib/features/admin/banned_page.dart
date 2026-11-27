import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';

const String kDefaultBanReason = 'Tài khoản có hành vi vi phạm lặp lại.';

/// Màn tài khoản bị khoá (MSG-06). Không có đường quay lại ngoài "Đăng xuất".
class BannedPage extends StatelessWidget {
  const BannedPage({super.key, this.reason});

  /// Lý do khoá; null hoặc rỗng thì dùng [kDefaultBanReason].
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final trimmed = (reason ?? '').trim();
    final text = trimmed.isEmpty ? kDefaultBanReason : trimmed;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircleAvatar(
                          radius: 36,
                          backgroundColor: AppColors.dangerSoft,
                          child: Icon(Icons.block,
                              size: 36, color: AppColors.danger),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Tài khoản của bạn đã bị khoá',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Lý do: $text',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.muted),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Bạn vẫn có thể xem nội dung công khai nhưng không '
                          'thể đăng tin, nhắn tin hay báo cáo.',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: AppButton(
                  label: 'Đăng xuất',
                  kind: AppButtonKind.secondary,
                  // Khung thật của TV2 sẽ xoá phiên rồi chuyển về màn đăng nhập.
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
