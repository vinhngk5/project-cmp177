import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tv4_app/core/theme.dart';
import 'package:tv4_app/features/report/report_demo_repository.dart';
import 'package:tv4_app/features/report/report_format.dart';
import 'package:tv4_app/features/report/report_routes.dart';
import 'package:tv4_prep/tv4_prep.dart';

Future<void> _pumpMine(WidgetTester tester, ReportRepository repo) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(),
    initialRoute: kMyReportsRoute,
    routes: reportRoutes(repository: repo),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('danh sách hiển thị tiêu đề, lý do và đủ ba trạng thái',
      (tester) async {
    await _pumpMine(tester, DemoReportRepository());

    expect(find.text('Giáo trình Giải tích 1'), findsOneWidget);
    expect(find.text('Điện thoại Samsung A12'), findsOneWidget);
    expect(find.text('Xe đạp Giant cũ'), findsOneWidget);
    expect(find.text('Lý do: Thông tin hoặc hình ảnh sai sự thật'),
        findsOneWidget);
    expect(find.text('Đang chờ xử lý'), findsOneWidget);
    expect(find.text('Đã xử lý'), findsOneWidget);
    expect(find.text('Không vi phạm'), findsOneWidget);
    expect(find.textContaining('Gửi lúc'), findsNWidgets(3));
  });

  testWidgets('màu huy hiệu: chờ = warning, đã xử lý = success, không vi phạm = muted',
      (tester) async {
    await _pumpMine(tester, DemoReportRepository());

    Color fg(String label) =>
        tester.widget<Text>(find.text(label)).style!.color!;
    expect(fg('Đang chờ xử lý'), AppColors.warning);
    expect(fg('Đã xử lý'), AppColors.success);
    expect(fg('Không vi phạm'), AppColors.muted);
  });

  testWidgets('chạm vào báo cáo mở chi tiết có kết quả xử lý', (tester) async {
    await _pumpMine(tester, DemoReportRepository());

    await tester.tap(find.text('Điện thoại Samsung A12'));
    await tester.pumpAndSettle();

    expect(find.text('Chi tiết báo cáo'), findsOneWidget);
    expect(find.text('Điện thoại Samsung A12'), findsOneWidget);
    expect(find.text('Lý do'), findsOneWidget);
    expect(find.text('Có dấu hiệu lừa đảo'), findsOneWidget);
    expect(find.text('Mô tả của bạn'), findsOneWidget);
    expect(find.text('Ảnh và mô tả không trùng khớp với sản phẩm.'),
        findsOneWidget);
    expect(find.text('Gửi lúc'), findsOneWidget);
    expect(find.text('Kết quả xử lý'), findsOneWidget);
    expect(find.text('Tin đăng đã bị gỡ do thông tin không chính xác.'),
        findsOneWidget);
    expect(find.text('Đã xử lý'), findsOneWidget);
  });

  testWidgets('chi tiết báo cáo đang chờ không có mục kết quả xử lý',
      (tester) async {
    await _pumpMine(tester, DemoReportRepository());

    await tester.tap(find.text('Giáo trình Giải tích 1'));
    await tester.pumpAndSettle();

    expect(find.text('Chi tiết báo cáo'), findsOneWidget);
    expect(find.text('Đang chờ xử lý'), findsOneWidget);
    expect(find.text('Kết quả xử lý'), findsNothing);
  });

  testWidgets('danh sách rỗng', (tester) async {
    await _pumpMine(tester, FakeReportRepository(seed: false));

    expect(find.text('Bạn chưa gửi báo cáo nào'), findsOneWidget);
  });

  testWidgets('hiển thị trạng thái đang tải', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      initialRoute: kMyReportsRoute,
      routes: reportRoutes(repository: FakeReportRepository()),
    ));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('lỗi mạng hiện thông báo và thử lại được', (tester) async {
    final repo = FakeReportRepository();
    repo.faults.offline = true;
    await _pumpMine(tester, repo);

    expect(find.text(kMsgOffline), findsOneWidget);

    repo.faults.offline = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(find.text(kMsgOffline), findsNothing);
    expect(find.text('Đang chờ xử lý'), findsOneWidget);
  });

  testWidgets('kéo để làm mới tải lại dữ liệu', (tester) async {
    final repo = FakeReportRepository(seed: false);
    await _pumpMine(tester, repo);
    expect(find.text('Bạn chưa gửi báo cáo nào'), findsOneWidget);

    await repo.createReport('prd_x', ReportReason.spam, null);
    await tester.fling(find.byType(Scrollable).first, const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Bạn chưa gửi báo cáo nào'), findsNothing);
    expect(find.text('Lý do: Spam, đăng trùng lặp'), findsOneWidget);
  });

  group('định dạng', () {
    test('formatVnd', () {
      expect(formatVnd(0), '0 ₫');
      expect(formatVnd(999), '999 ₫');
      expect(formatVnd(45000), '45.000 ₫');
      expect(formatVnd(1200000), '1.200.000 ₫');
    });

    test('formatDateTime', () {
      final t = DateTime(2026, 11, 27, 13, 5);
      expect(formatDateTimeFull(t), '27/11/2026, 13:05');
      expect(formatDateTimeShort(t, now: DateTime(2026, 12, 1)), '27/11, 13:05');
      expect(formatDateTimeShort(t, now: DateTime(2027, 1, 1)),
          '27/11/2026, 13:05');
    });

    test('nhãn trạng thái', () {
      expect(reportStatusLabel(ReportStatus.pending), 'Đang chờ xử lý');
      expect(reportStatusLabel(ReportStatus.resolved), 'Đã xử lý');
      expect(reportStatusLabel(ReportStatus.rejected), 'Không vi phạm');
    });
  });
}
