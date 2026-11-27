import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:tv4_prep/tv4_prep.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'admin_format.dart';

/// Tên route chi tiết; khai báo ở admin_routes.dart (không import vòng).
const String _kReportRoute = '/admin/report';

/// Hàng đợi báo cáo của Admin (FR-ADMIN-02). Không có nội dung chat ở bất kỳ đâu.
class AdminQueuePage extends StatefulWidget {
  const AdminQueuePage({super.key, required this.repository});

  final AdminRepository repository;

  @override
  State<AdminQueuePage> createState() => _AdminQueuePageState();
}

class _AdminQueuePageState extends State<AdminQueuePage> {
  late final AdminController _controller;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = AdminController(repository: widget.repository);
    _scroll.addListener(_onScroll);
    unawaited(_controller.loadReports());
  }

  @override
  void dispose() {
    _scroll.dispose();
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.hasClients &&
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      unawaited(_controller.loadMore());
    }
  }

  Future<void> _open(AdminReportItem item) async {
    final changed =
        await Navigator.of(context).pushNamed<bool>(_kReportRoute, arguments: item.id);
    if (!mounted) return;
    if (changed == true) {
      unawaited(_controller.loadReports());
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(kMsgAdminResolved)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AdminState>(
      stream: _controller.states,
      initialData: _controller.state,
      builder: (context, snapshot) {
        final s = snapshot.data ?? _controller.state;
        return Scaffold(
          appBar: AppBar(title: const Text('Quản trị – Báo cáo')),
          body: s.accessDenied
              ? const AdminAccessDenied()
              : Column(
                  children: [
                    _FilterBar(
                      selected: s.statusFilter,
                      onSelected: (f) => unawaited(_controller.setFilter(f)),
                    ),
                    const Divider(),
                    Expanded(child: _buildBody(s)),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildBody(AdminState s) {
    final firstLoad =
        s.items.isEmpty && (s.loadingList || s.page == 0) && s.error == null;
    if (firstLoad) {
      return const Center(child: CircularProgressIndicator());
    }
    if (s.items.isEmpty && s.error != null) {
      return ErrorState(
        message: s.error!,
        onRetry: () => unawaited(_controller.loadReports()),
      );
    }
    if (s.items.isEmpty) {
      final pending = s.statusFilter == ReportStatus.pending;
      return RefreshIndicator(
        onRefresh: _controller.loadReports,
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: c.maxHeight,
              child: EmptyState(
                icon: pending ? Icons.check : Icons.inbox_outlined,
                iconColor: pending ? AppColors.success : AppColors.muted,
                iconBackground:
                    pending ? AppColors.successSoft : AppColors.bubbleOther,
                title: pending
                    ? 'Không còn báo cáo nào chờ xử lý'
                    : 'Không có báo cáo nào',
              ),
            ),
          ),
        ),
      );
    }
    final hasFooter = s.loadingList || s.error != null;
    return RefreshIndicator(
      onRefresh: _controller.loadReports,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: s.items.length + (hasFooter ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(),
        itemBuilder: (context, i) {
          if (i >= s.items.length) {
            return _ListFooter(state: s, onRetry: _controller.loadMore);
          }
          final item = s.items[i];
          return _ReportTile(item: item, onTap: () => _open(item));
        },
      ),
    );
  }
}

/// Màn dùng chung khi server trả 403 (E-05).
class AdminAccessDenied extends StatelessWidget {
  const AdminAccessDenied({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.lock_outline,
      iconColor: AppColors.danger,
      iconBackground: AppColors.dangerSoft,
      title: 'Bạn không có quyền truy cập',
      message: 'Khu vực này chỉ dành cho quản trị viên.',
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelected});

  final ReportStatus? selected;
  final ValueChanged<ReportStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    final options = <(String, ReportStatus?)>[
      ('Chờ xử lý', ReportStatus.pending),
      ('Đã xử lý', ReportStatus.resolved),
      ('Tất cả', null),
    ];
    return Container(
      color: AppColors.surface,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        children: [
          for (final o in options)
            ChoiceChip(
              label: Text(o.$1),
              selected: selected == o.$2,
              showCheckmark: false,
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.bg,
              side: BorderSide.none,
              shape: const StadiumBorder(),
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected == o.$2 ? AppColors.onPrimary : AppColors.text,
              ),
              onSelected: (_) => onSelected(o.$2),
            ),
        ],
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.item, required this.onTap});

  final AdminReportItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = reportStatusStyle(item.status);
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.warningSoft,
                child: Icon(Icons.warning_amber_rounded,
                    size: 20, color: AppColors.warning),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // API danh sách chưa trả tên sản phẩm snapshot / người báo cáo
                    // nên dùng lý do làm tiêu đề và mã tin làm dòng phụ.
                    Text(
                      reasonLabel(item.reason),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Mã tin: ${item.targetId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted),
                    ),
                    Text(
                      formatWhen(item.createdAt),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(label: label, background: bg, foreground: fg),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.state, required this.onRetry});

  final AdminState state;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.loadingList) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return TextButton(
      onPressed: () => unawaited(onRetry()),
      child: Text('${state.error} Chạm để thử lại.'),
    );
  }
}
