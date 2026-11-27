import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tv4_app/core/theme.dart';
import 'package:tv4_app/core/widgets.dart';
import 'package:tv4_app/features/admin/admin_routes.dart';
import 'package:tv4_prep/tv4_prep.dart';

const _misleading = 'Thông tin hoặc hình ảnh sai sự thật';
const _spam = 'Spam, đăng trùng lặp';
const _banLabel = 'Gỡ tin + khoá chủ tin';

Widget _app(FakeAdminRepository repo, {String initialRoute = kAdminQueueRoute}) {
  return MaterialApp(
    theme: buildAppTheme(),
    initialRoute: initialRoute,
    routes: adminRoutes(repository: repo),
  );
}

Widget _detailApp(FakeAdminRepository repo, {String id = 'rpt_01JREPORT1'}) {
  return MaterialApp(
    theme: buildAppTheme(),
    home: AdminReportDetailPage(repository: repo, reportId: id),
  );
}

void _bigScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Nút dạng FilledButton / OutlinedButton chứa nhãn [label].
ButtonStyleButton _button(WidgetTester tester, String label) {
  final finder = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  );
  return tester.widget<ButtonStyleButton>(finder);
}

void main() {
  group('Hàng đợi báo cáo', () {
    testWidgets('hiển thị dữ liệu mẫu và lọc theo trạng thái', (tester) async {
      _bigScreen(tester);
      final repo = FakeAdminRepository()
        ..addReport(
          id: 'rpt_done',
          status: ReportStatus.resolved,
          reason: ReportReason.spam,
          productId: 'prd_done',
        );
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      expect(find.text('Quản trị – Báo cáo'), findsOneWidget);
      // Mặc định: chờ xử lý.
      expect(find.text(_misleading), findsOneWidget);
      expect(find.text('Mã tin: prd_01JPRODUCT1'), findsOneWidget);
      expect(find.text('Chờ xử lý'), findsNWidgets(2)); // chip + badge
      expect(find.text(_spam), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Đã xử lý'));
      await tester.pumpAndSettle();
      expect(find.text(_spam), findsOneWidget);
      expect(find.text(_misleading), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Tất cả'));
      await tester.pumpAndSettle();
      expect(find.text(_spam), findsOneWidget);
      expect(find.text(_misleading), findsOneWidget);
    });

    testWidgets('hàng đợi rỗng', (tester) async {
      await tester.pumpWidget(_app(FakeAdminRepository(seed: false)));
      await tester.pumpAndSettle();
      expect(find.text('Không còn báo cáo nào chờ xử lý'), findsOneWidget);
      expect(find.byType(StatusBadge), findsNothing);
    });

    testWidgets('lỗi mạng hiện ErrorState và thử lại được', (tester) async {
      final repo = FakeAdminRepository()..faults.offline = true;
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.text(kMsgOffline), findsOneWidget);

      repo.faults.offline = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorState), findsNothing);
      expect(find.text(_misleading), findsOneWidget);
    });

    testWidgets('server trả 403 hiện màn không có quyền', (tester) async {
      final repo = FakeAdminRepository()..isAdmin = false;
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();
      expect(find.text('Bạn không có quyền truy cập'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
    });

    testWidgets('cuộn xuống cuối thì tải thêm trang kế', (tester) async {
      final repo = FakeAdminRepository(seed: false)..seedReports(25);
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();
      expect(find.text('Mã tin: prd_fake_21'), findsNothing);

      await tester.scrollUntilVisible(
        find.text('Mã tin: prd_fake_25'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(find.text('Mã tin: prd_fake_25'), findsOneWidget);
    });
  });

  group('Chi tiết báo cáo', () {
    testWidgets('hiển thị snapshot sản phẩm, lý do, mô tả, người báo cáo',
        (tester) async {
      _bigScreen(tester);
      await tester.pumpWidget(_detailApp(FakeAdminRepository()));
      await tester.pumpAndSettle();

      expect(find.text('Chi tiết báo cáo'), findsOneWidget);
      expect(find.text('Ảnh chụp tin tại thời điểm báo cáo'), findsOneWidget);
      expect(find.text('Giao trinh Giai tich 1'), findsOneWidget);
      expect(find.text('45.000 ₫'), findsOneWidget);
      expect(find.text('Đang đăng bán'), findsOneWidget);
      expect(find.text(_misleading), findsOneWidget);
      expect(find.text('Thong tin khong trung khop.'), findsOneWidget);
      expect(find.text('Nguyen B'), findsOneWidget);
      expect(find.text('0/500'), findsOneWidget);
      expect(find.text('Báo cáo này đã được xử lý.'), findsNothing);
      expect(_button(tester, 'Không vi phạm').onPressed, isNotNull);
      expect(_button(tester, 'Gỡ tin').onPressed, isNotNull);
      expect(_button(tester, _banLabel).onPressed, isNotNull);
    });

    testWidgets('ghi chú quá ngắn báo lỗi dưới ô và không gọi server',
        (tester) async {
      _bigScreen(tester);
      final repo = FakeAdminRepository();
      await tester.pumpWidget(_detailApp(repo));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Ok');
      await tester.pump();
      expect(find.text('2/500'), findsOneWidget);

      await tester.tap(find.text('Gỡ tin'));
      await tester.pumpAndSettle();
      expect(find.text('Ghi chú tối thiểu 5 ký tự.'), findsOneWidget);
      expect(repo.resolveCalls, 0);

      // Gõ tiếp thì lỗi biến mất.
      await tester.enterText(find.byType(TextField), 'Ok roi nhe');
      await tester.pump();
      expect(find.text('Ghi chú tối thiểu 5 ký tự.'), findsNothing);
    });

    testWidgets('gỡ tin + khoá phải qua hộp xác nhận; Huỷ thì không gọi server',
        (tester) async {
      _bigScreen(tester);
      final repo = FakeAdminRepository();
      await tester.pumpWidget(_detailApp(repo));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Tin co dau hieu lua dao.');
      await tester.tap(find.text(_banLabel));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Gỡ tin và khoá chủ tin?'), findsOneWidget);
      expect(find.text('Huỷ'), findsOneWidget);
      expect(find.text('Xác nhận khoá'), findsOneWidget);
      expect(repo.resolveCalls, 0);

      await tester.tap(find.text('Huỷ'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(repo.resolveCalls, 0);
    });

    testWidgets('xác nhận khoá gọi resolve với đúng hành động và ghi chú',
        (tester) async {
      _bigScreen(tester);
      final repo = FakeAdminRepository();
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text(_misleading));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  Tin co dau hieu lua dao.  ');
      await tester.tap(find.text(_banLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận khoá'));
      await tester.pumpAndSettle();

      expect(repo.resolveCalls, 1);
      expect(repo.lastAction, AdminAction.removeProductAndBanOwner);
      expect(repo.lastNote, 'Tin co dau hieu lua dao.');
      // Đã quay lại hàng đợi, báo cáo đã xử lý biến khỏi bộ lọc "Chờ xử lý".
      expect(find.text('Quản trị – Báo cáo'), findsOneWidget);
      expect(find.text('Không còn báo cáo nào chờ xử lý'), findsOneWidget);
      expect(find.text(kMsgAdminResolved), findsOneWidget);
    });

    testWidgets('Gỡ tin thành công quay lại hàng đợi, còn lại báo cáo khác',
        (tester) async {
      _bigScreen(tester);
      final repo = FakeAdminRepository(seed: false)
        ..addReport(id: 'a', reason: ReportReason.scam, productId: 'prd_a')
        ..addReport(id: 'b', reason: ReportReason.fake, productId: 'prd_b');
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mã tin: prd_a'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Dung la lua dao');
      await tester.tap(find.text('Gỡ tin'));
      await tester.pumpAndSettle();

      expect(repo.lastAction, AdminAction.removeProduct);
      expect(find.text('Quản trị – Báo cáo'), findsOneWidget);
      expect(find.text('Mã tin: prd_a'), findsNothing);
      expect(find.text('Mã tin: prd_b'), findsOneWidget);
    });

    testWidgets('báo cáo đã xử lý (canResolve=false) hiện banner và khoá nút',
        (tester) async {
      _bigScreen(tester);
      final repo = FakeAdminRepository()..markResolvedElsewhere('rpt_01JREPORT1');
      await tester.pumpWidget(_detailApp(repo));
      await tester.pumpAndSettle();

      expect(find.byType(InfoBanner), findsOneWidget);
      expect(find.text('Báo cáo này đã được xử lý.'), findsOneWidget);
      expect(_button(tester, 'Không vi phạm').onPressed, isNull);
      expect(_button(tester, 'Gỡ tin').onPressed, isNull);
      expect(_button(tester, _banLabel).onPressed, isNull);
    });

    testWidgets('409 khi đang xử lý: hiện banner và vô hiệu 3 nút',
        (tester) async {
      _bigScreen(tester);
      final repo = FakeAdminRepository();
      await tester.pumpWidget(_detailApp(repo));
      await tester.pumpAndSettle();

      // Admin khác xử lý xong trong lúc màn này đang mở.
      repo.markResolvedElsewhere('rpt_01JREPORT1');
      repo.faults.failOnce(ApiException(httpStatus: 409, code: 'REPORT_ALREADY_RESOLVED'));
      // failOnce tiêu thụ ở lời gọi kế tiếp (resolve); lần tải lại sau 409 chạy bình thường.
      await tester.enterText(find.byType(TextField), 'Da co nguoi xu ly');
      await tester.tap(find.text('Gỡ tin'));
      await tester.pumpAndSettle();

      expect(find.text('Báo cáo này đã được xử lý.'), findsOneWidget);
      expect(_button(tester, 'Không vi phạm').onPressed, isNull);
      expect(_button(tester, 'Gỡ tin').onPressed, isNull);
      expect(_button(tester, _banLabel).onPressed, isNull);
      // Vẫn ở trang chi tiết, không pop.
      expect(find.text('Chi tiết báo cáo'), findsOneWidget);
    });

    testWidgets('server trả 403 hiện màn không có quyền', (tester) async {
      final repo = FakeAdminRepository()..isAdmin = false;
      await tester.pumpWidget(_detailApp(repo));
      await tester.pumpAndSettle();
      expect(find.text('Bạn không có quyền truy cập'), findsOneWidget);
      expect(find.byType(AppButton), findsNothing);
    });

    testWidgets('không tìm thấy báo cáo hiện lỗi có nút thử lại', (tester) async {
      await tester.pumpWidget(_detailApp(FakeAdminRepository(), id: 'khong_co'));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    });
  });

  group('Tài khoản bị khoá', () {
    testWidgets('hiển thị lý do mặc định', (tester) async {
      await tester.pumpWidget(_app(FakeAdminRepository(), initialRoute: kBannedRoute));
      await tester.pumpAndSettle();
      expect(find.text('Tài khoản của bạn đã bị khoá'), findsOneWidget);
      expect(find.text('Lý do: Tài khoản có hành vi vi phạm lặp lại.'), findsOneWidget);
      expect(find.text('Đăng xuất'), findsOneWidget);
    });

    testWidgets('hiển thị lý do truyền qua arguments và Đăng xuất quay về /',
        (tester) async {
      final repo = FakeAdminRepository();
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        routes: {
          '/': (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context)
                        .pushNamed(kBannedRoute, arguments: 'Lừa đảo nhiều lần.'),
                    child: const Text('mở'),
                  ),
                ),
              ),
          ...adminRoutes(repository: repo),
        },
      ));
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();
      expect(find.text('Lý do: Lừa đảo nhiều lần.'), findsOneWidget);

      await tester.tap(find.text('Đăng xuất'));
      await tester.pumpAndSettle();
      expect(find.text('mở'), findsOneWidget);
      expect(find.text('Tài khoản của bạn đã bị khoá'), findsNothing);
    });
  });
}
