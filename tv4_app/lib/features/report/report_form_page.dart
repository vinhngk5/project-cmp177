import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:tv4_prep/tv4_prep.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'report_format.dart';
import 'report_routes.dart';

/// Màn "Báo cáo tin đăng" (FR-REPORT-01..08).
class ReportFormPage extends StatefulWidget {
  const ReportFormPage({
    super.key,
    required this.repository,
    required this.args,
  });

  final ReportRepository repository;
  final ReportFormArgs args;

  @override
  State<ReportFormPage> createState() => _ReportFormPageState();
}

class _ReportFormPageState extends State<ReportFormPage> {
  late final ReportController _controller;
  late final StreamSubscription<ReportState> _subscription;
  final TextEditingController _description = TextEditingController();

  ReportReason? _reason;
  String? _reasonError;
  String? _descriptionError;

  @override
  void initState() {
    super.initState();
    _controller = ReportController(
      productId: widget.args.productId,
      repository: widget.repository,
    );
    _subscription = _controller.states.listen(_onState);
  }

  @override
  void dispose() {
    _subscription.cancel();
    _controller.dispose();
    _description.dispose();
    super.dispose();
  }

  /// Hiệu ứng phụ theo trạng thái controller: điều hướng khi thành công,
  /// SnackBar khi lỗi từ server / mạng. Input được giữ nguyên.
  void _onState(ReportState s) {
    if (!mounted) return;
    if (s.isSuccess) {
      Navigator.of(context).pushReplacementNamed(kReportSuccessRoute);
    } else if (s.status == ReportSubmitStatus.error && s.errorMessage != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(s.errorMessage!),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
        ));
    }
  }

  void _submit() {
    // Validate trước để hiển thị lỗi ngay dưới đúng ô; controller validate lại.
    final description = _description.text;
    final error = validateReport(reason: _reason, description: description);
    setState(() {
      _reasonError = _reason == null ? error : null;
      _descriptionError = _reason != null ? error : null;
    });
    if (error != null) return;
    _controller.submit(_reason, description);
  }

  void _selectReason(ReportReason? value) {
    if (_controller.state.isSubmitting) return;
    setState(() {
      _reason = value;
      _reasonError = null;
      // Đổi lý do có thể làm lỗi mô tả (OTHER) không còn đúng.
      _descriptionError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo tin đăng')),
      body: StreamBuilder<ReportState>(
        stream: _controller.states,
        initialData: _controller.state,
        builder: (context, snapshot) {
          final submitting = snapshot.data?.isSubmitting ?? false;
          return Column(
            children: [
              _ProductCard(args: widget.args),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(error: _reasonError),
                      _ReasonList(
                        value: _reason,
                        enabled: !submitting,
                        onChanged: _selectReason,
                      ),
                      _DescriptionField(
                        controller: _description,
                        enabled: !submitting,
                        errorText: _descriptionError,
                        onChanged: () => setState(() => _descriptionError = null),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.all(16),
                child: SafeArea(
                  top: false,
                  child: AppButton(
                    label: submitting ? 'Đang gửi…' : 'Gửi báo cáo',
                    onPressed: submitting ? null : _submit,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.args});

  final ReportFormArgs args;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.bubbleOther,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bạn đang báo cáo',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
                Text(
                  args.productTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                Text(
                  formatVnd(args.priceVnd),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lý do báo cáo',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                error!,
                style: const TextStyle(fontSize: 12, color: AppColors.danger),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReasonList extends StatelessWidget {
  const _ReasonList({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final ReportReason? value;
  final bool enabled;
  final ValueChanged<ReportReason?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: RadioGroup<ReportReason>(
        groupValue: value,
        onChanged: onChanged,
        child: Column(
          children: [
            for (final reason in ReportReason.values) ...[
              RadioListTile<ReportReason>(
                value: reason,
                enabled: enabled,
                dense: true,
                visualDensity: VisualDensity.compact,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                title: Text(
                  reason.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        reason == value ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
              if (reason != ReportReason.values.last) const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }
}

class _DescriptionField extends StatelessWidget {
  const _DescriptionField({
    required this.controller,
    required this.enabled,
    required this.errorText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final String? errorText;
  final VoidCallback onChanged;

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => TextField(
          controller: controller,
          enabled: enabled,
          minLines: 4,
          maxLines: 6,
          maxLength: kReportDescriptionMaxLength,
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(
            hintText: 'Mô tả thêm (không bắt buộc)…',
            hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
            filled: true,
            fillColor: AppColors.surface,
            errorText: errorText,
            counterText: '${value.text.length}/$kReportDescriptionMaxLength',
            border: _border(AppColors.border),
            enabledBorder: _border(AppColors.border),
            disabledBorder: _border(AppColors.border),
            focusedBorder: _border(AppColors.primary),
            errorBorder: _border(AppColors.danger),
            focusedErrorBorder: _border(AppColors.danger),
          ),
        ),
      ),
    );
  }
}
