import 'package:material_ui/material_ui.dart';
import 'package:tv4_prep/tv4_prep.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'report_format.dart';
import 'report_routes.dart';
import 'report_widgets.dart';

enum _LoadStatus { loading, loaded, error }

/// Màn "Báo cáo của tôi" (API-REPORT-02).
class MyReportsPage extends StatefulWidget {
  const MyReportsPage({super.key, required this.repository, this.now});

  final ReportRepository repository;

  /// Chỉ để test: thời điểm "hiện tại" khi định dạng ngày.
  final DateTime Function()? now;

  @override
  State<MyReportsPage> createState() => _MyReportsPageState();
}

class _MyReportsPageState extends State<MyReportsPage> {
  _LoadStatus _status = _LoadStatus.loading;
  List<MyReport> _items = const [];
  int _page = 1;
  bool _hasMore = false;
  bool _loadingMore = false;
  String _errorMessage = kMsgGeneric;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Tải lại từ trang 1. [showSpinner] false khi kéo để làm mới.
  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) setState(() => _status = _LoadStatus.loading);
    try {
      final result = await widget.repository.myReports(1);
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _page = 1;
        _hasMore = result.hasMore;
        _status = _LoadStatus.loaded;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = errorMessageOf(e);
        _status = _LoadStatus.error;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final result = await widget.repository.myReports(_page + 1);
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...result.items];
        _page += 1;
        _hasMore = result.hasMore;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMessageOf(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo của tôi')),
      body: switch (_status) {
        _LoadStatus.loading => const Center(child: CircularProgressIndicator()),
        _LoadStatus.error =>
          ErrorState(message: _errorMessage, onRetry: _load),
        _LoadStatus.loaded => RefreshIndicator(
            onRefresh: () => _load(showSpinner: false),
            child: _items.isEmpty ? _buildEmpty() : _buildList(),
          ),
      },
    );
  }

  /// Rỗng vẫn cuộn được để kéo làm mới.
  Widget _buildEmpty() {
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: constraints.maxHeight,
            child: const EmptyState(
              icon: Icons.flag_outlined,
              title: 'Bạn chưa gửi báo cáo nào',
              message: 'Các báo cáo tin đăng bạn gửi sẽ hiện ở đây.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final now = (widget.now ?? DateTime.now)();
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        if (i == _items.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: AppButton(
              label: 'Tải thêm',
              kind: AppButtonKind.secondary,
              loading: _loadingMore,
              onPressed: _loadMore,
            ),
          );
        }
        final r = _items[i];
        return _ReportTile(
          report: r,
          now: now,
          onTap: () => Navigator.of(context)
              .pushNamed(kReportDetailRoute, arguments: r),
        );
      },
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.report,
    required this.now,
    required this.onTap,
  });

  final MyReport report;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const meta = TextStyle(fontSize: 12, color: AppColors.muted);
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reportTitleOf(report),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Lý do: ${reportReasonLabel(report.reason)}', style: meta),
                    const SizedBox(height: 2),
                    Text(
                      'Gửi lúc ${formatDateTimeShort(report.createdAt, now: now)}',
                      style: meta,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ReportStatusBadge(status: report.status),
            ],
          ),
        ),
      ),
    );
  }
}
