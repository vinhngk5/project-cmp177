import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:tv4_prep/tv4_prep.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'admin_format.dart';
import 'admin_queue_page.dart' show AdminAccessDenied;

/// Chi tiết một báo cáo và xử lý (FR-ADMIN-03/04/05).
/// Chỉ hiển thị snapshot sản phẩm, lý do, mô tả, người báo cáo; không có nội dung chat.
/// Pop với `true` khi xử lý thành công để hàng đợi tải lại.
class AdminReportDetailPage extends StatefulWidget {
  const AdminReportDetailPage({
    super.key,
    required this.repository,
    required this.reportId,
  });

  final AdminRepository repository;
  final String reportId;

  @override
  State<AdminReportDetailPage> createState() => _AdminReportDetailPageState();
}

class _AdminReportDetailPageState extends State<AdminReportDetailPage> {
  late final AdminController _controller;
  final TextEditingController _note = TextEditingController();
  String? _noteError;
  AdminAction? _activeAction;

  @override
  void initState() {
    super.initState();
    _controller = AdminController(repository: widget.repository);
    unawaited(_controller.openDetail(widget.reportId));
  }

  @override
  void dispose() {
    _note.dispose();
    unawaited(_controller.dispose());
    super.dispose();
  }

  Future<bool> _confirmBan() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gỡ tin và khoá chủ tin?'),
        content: const Text(
          'Tin sẽ bị ẩn khỏi mọi người. Tài khoản chủ tin bị khoá và không '
          'thể ghi dữ liệu. Thao tác được ghi lại trong nhật ký quản trị.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.onPrimary,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xác nhận khoá'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _submit(AdminAction action) async {
    final invalid = validateAdminNote(_note.text);
    setState(() => _noteError = invalid);
    if (invalid != null) return;
    if (action == AdminAction.removeProductAndBanOwner && !await _confirmBan()) {
      return;
    }
    if (!mounted) return;
    setState(() => _activeAction = action);
    final ok = await _controller.resolve(action, _note.text);
    if (!mounted) return;
    setState(() => _activeAction = null);
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AdminState>(
      stream: _controller.states,
      initialData: _controller.state,
      builder: (context, snapshot) {
        final s = snapshot.data ?? _controller.state;
        return Scaffold(
          appBar: AppBar(title: const Text('Chi tiết báo cáo')),
          body: _buildBody(s),
        );
      },
    );
  }

  Widget _buildBody(AdminState s) {
    if (s.accessDenied) return const AdminAccessDenied();
    final detail = s.detail;
    if (detail == null) {
      if (s.error != null && !s.loadingDetail) {
        return ErrorState(
          message: s.error!,
          onRetry: () => unawaited(_controller.openDetail(widget.reportId)),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    final canAct = detail.canResolve && !s.resolving;
    return Column(
      children: [
        if (!detail.canResolve) const InfoBanner(text: kMsgReportAlreadyResolved),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('Ảnh chụp tin tại thời điểm báo cáo'),
                const SizedBox(height: 8),
                _SnapshotCard(detail: detail),
                const SizedBox(height: 16),
                const _SectionLabel('Lý do'),
                _Value(reasonLabel(detail.reason)),
                if ((detail.description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const _SectionLabel('Mô tả của người báo cáo'),
                  _Value(detail.description!.trim()),
                ],
                const SizedBox(height: 12),
                const _SectionLabel('Người báo cáo'),
                _Value(detail.reporterName),
                const SizedBox(height: 16),
                const _SectionLabel(
                    'Ghi chú xử lý (bắt buộc, tối thiểu $kAdminNoteMinLength ký tự)'),
                const SizedBox(height: 6),
                TextField(
                  controller: _note,
                  enabled: canAct,
                  maxLines: 3,
                  maxLength: kAdminNoteMaxLength,
                  onChanged: (_) {
                    setState(() {
                      if (_noteError != null) _noteError = null;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Nhập ghi chú xử lý…',
                    filled: true,
                    fillColor: AppColors.surface,
                    errorText: _noteError,
                    counterText: '${_note.text.length}/$kAdminNoteMaxLength',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.danger),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.danger),
                    ),
                  ),
                ),
                if (detail.canResolve && s.error != null) ...[
                  const SizedBox(height: 8),
                  Text(s.error!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.danger)),
                ],
              ],
            ),
          ),
        ),
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppButton(
                  label: adminActionLabel(AdminAction.rejectReport),
                  kind: AppButtonKind.secondary,
                  loading: s.resolving && _activeAction == AdminAction.rejectReport,
                  onPressed:
                      canAct ? () => _submit(AdminAction.rejectReport) : null,
                ),
                const SizedBox(height: 8),
                AppButton(
                  label: adminActionLabel(AdminAction.removeProduct),
                  loading: s.resolving && _activeAction == AdminAction.removeProduct,
                  onPressed:
                      canAct ? () => _submit(AdminAction.removeProduct) : null,
                ),
                const SizedBox(height: 8),
                AppButton(
                  label: adminActionLabel(AdminAction.removeProductAndBanOwner),
                  kind: AppButtonKind.danger,
                  loading: s.resolving &&
                      _activeAction == AdminAction.removeProductAndBanOwner,
                  onPressed: canAct
                      ? () => _submit(AdminAction.removeProductAndBanOwner)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 12, color: AppColors.muted),
      );
}

class _Value extends StatelessWidget {
  const _Value(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(text, style: const TextStyle(fontSize: 14)),
      );
}

class _SnapshotCard extends StatelessWidget {
  const _SnapshotCard({required this.detail});
  final AdminReportDetail detail;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = productStatusStyle(detail.targetStatus);
    final url = detail.snapshotCoverImageUrl;
    const placeholder = Icon(Icons.image_outlined, color: AppColors.muted);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.bubbleOther,
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: url == null
              ? placeholder
              : Image.network(url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => placeholder),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail.snapshotTitle,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                formatVnd(detail.snapshotPriceVnd),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text('Hiện tại: ',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.muted)),
                  StatusBadge(label: label, background: bg, foreground: fg),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
