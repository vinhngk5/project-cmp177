/// Widget dùng chung tối thiểu cho các màn của TV4 (khớp component trong Figma).
/// Khi TV2 có UI Kit chung thì chuyển các widget này sang bản của nhóm.
library;

import 'package:material_ui/material_ui.dart';

import 'theme.dart';

enum AppButtonKind { primary, secondary, danger }

/// Nút toàn chiều rộng (Btn/Primary, Btn/Secondary, Btn/Danger trong Figma).
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = AppButtonKind.primary,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonKind kind;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    const pad = EdgeInsets.symmetric(horizontal: 16, vertical: 14);
    final text = loading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500));
    final VoidCallback? cb = enabled ? onPressed : null;

    final Widget button = switch (kind) {
      AppButtonKind.secondary => OutlinedButton(
          onPressed: cb,
          style: OutlinedButton.styleFrom(
            padding: pad,
            shape: shape,
            foregroundColor: AppColors.text,
            backgroundColor: AppColors.surface,
            side: const BorderSide(color: AppColors.border),
          ),
          child: text,
        ),
      AppButtonKind.danger => FilledButton(
          onPressed: cb,
          style: FilledButton.styleFrom(
            padding: pad,
            shape: shape,
            backgroundColor: AppColors.danger,
            foregroundColor: AppColors.onPrimary,
          ),
          child: text,
        ),
      AppButtonKind.primary => FilledButton(
          onPressed: cb,
          style: FilledButton.styleFrom(
            padding: pad,
            shape: shape,
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
          ),
          child: text,
        ),
    };
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Nhãn trạng thái dạng viên thuốc (Đang chờ xử lý / Đã xử lý / ...).
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: foreground),
      ),
    );
  }
}

/// Dải thông báo ngang (cảnh báo, mẹo an toàn, chỉ đọc...).
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.text,
    this.background = AppColors.warningSoft,
    this.foreground = AppColors.warning,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(text, style: TextStyle(fontSize: 12, color: foreground)),
    );
  }
}

/// Trạng thái rỗng căn giữa (icon tròn + tiêu đề + mô tả).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.iconColor = AppColors.primary,
    this.iconBackground = AppColors.primarySoft,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Color iconColor;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: iconBackground,
              child: Icon(icon, size: 32, color: iconColor),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Màn lỗi tải dữ liệu có nút thử lại.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              AppButton(
                label: 'Thử lại',
                kind: AppButtonKind.secondary,
                expand: false,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Chữ cái đầu trong avatar tròn.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.size = 44});

  final String name;
  final double size;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.primarySoft,
      child: Text(
        _initials,
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w500,
          fontSize: size * 0.34,
        ),
      ),
    );
  }
}
