import 'package:material_ui/material_ui.dart';
import 'package:tv4_prep/tv4_prep.dart';

import 'admin_queue_page.dart';
import 'admin_report_detail_page.dart';
import 'banned_page.dart';

export 'admin_queue_page.dart' show AdminQueuePage;
export 'admin_report_detail_page.dart' show AdminReportDetailPage;
export 'banned_page.dart' show BannedPage;

/// Route của khu vực Admin.
const String kAdminQueueRoute = '/admin';

/// Chi tiết báo cáo; truyền id báo cáo (String) qua `arguments`.
const String kAdminReportRoute = '/admin/report';
const String kBannedRoute = '/banned';

/// Repository mẫu dùng chung cho cả ứng dụng thử (nhớ trạng thái giữa các màn).
final FakeAdminRepository _demoRepository = _buildDemoRepository();

FakeAdminRepository _buildDemoRepository() {
  final repo = FakeAdminRepository(); // có sẵn rpt_01JREPORT1 (PENDING)
  repo.addReport(
    id: 'rpt_demo_2',
    reason: ReportReason.scam,
    productId: 'prd_demo_2',
    title: 'Điện thoại Samsung A12',
  );
  repo.addReport(
    id: 'rpt_demo_3',
    reason: ReportReason.fake,
    productId: 'prd_demo_3',
    title: 'Áo khoác nam size L',
  );
  repo.addReport(
    id: 'rpt_demo_4',
    status: ReportStatus.resolved,
    reason: ReportReason.spam,
    productId: 'prd_demo_4',
    title: 'Bàn phím cơ',
  );
  return repo;
}

/// [repository] mặc định là bản Fake; TV2 thay bằng repository HTTP khi ghép khung.
Map<String, WidgetBuilder> adminRoutes({AdminRepository? repository}) {
  final repo = repository ?? _demoRepository;
  return {
    kAdminQueueRoute: (_) => AdminQueuePage(repository: repo),
    kAdminReportRoute: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      return AdminReportDetailPage(
        repository: repo,
        reportId: args is String ? args : '',
      );
    },
    kBannedRoute: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      return BannedPage(reason: args is String ? args : null);
    },
  };
}
