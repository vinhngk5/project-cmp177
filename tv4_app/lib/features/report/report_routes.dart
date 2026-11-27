import 'package:material_ui/material_ui.dart';
import 'package:tv4_prep/tv4_prep.dart';

import 'my_reports_page.dart';
import 'report_args.dart';
import 'report_demo_repository.dart';
import 'report_detail_page.dart';
import 'report_form_page.dart';
import 'report_success_page.dart';

export 'report_args.dart';

/// Route của khu vực Báo cáo.
const String kReportFormRoute = '/report/new';
const String kMyReportsRoute = '/report/mine';
const String kReportSuccessRoute = '/report/success';
const String kReportDetailRoute = '/report/detail';

/// Repository dùng chung giữa các màn (form tạo, danh sách đọc cùng dữ liệu).
final ReportRepository _sharedRepository = DemoReportRepository();

/// - [kReportFormRoute]: arguments là [ReportFormArgs] (thiếu thì dùng sản phẩm mẫu).
/// - [kReportDetailRoute]: arguments là [MyReport].
///
/// [repository] cho phép thay nguồn dữ liệu (test, API thật sau này).
Map<String, WidgetBuilder> reportRoutes({ReportRepository? repository}) {
  final repo = repository ?? _sharedRepository;
  return {
    kReportFormRoute: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      return ReportFormPage(
        repository: repo,
        args: args is ReportFormArgs ? args : ReportFormArgs.sample,
      );
    },
    kReportSuccessRoute: (_) => const ReportSuccessPage(),
    kMyReportsRoute: (_) => MyReportsPage(repository: repo),
    kReportDetailRoute: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      return args is MyReport
          ? ReportDetailPage(report: args)
          : const ReportDetailMissing();
    },
  };
}
