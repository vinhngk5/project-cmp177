import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tv4_app/core/theme.dart';
import 'package:tv4_app/features/report/report_form_page.dart';
import 'package:tv4_app/features/report/report_routes.dart';
import 'package:tv4_prep/tv4_prep.dart';

const _freshProduct = ReportFormArgs(
  productId: 'prd_fresh',
  productTitle: 'Xe đạp Giant cũ',
  priceVnd: 1200000,
);

Future<void> _pumpForm(
  WidgetTester tester,
  FakeReportRepository repo, {
  ReportFormArgs args = _freshProduct,
}) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(),
    home: ReportFormPage(repository: repo, args: args),
    routes: reportRoutes(repository: repo),
  ));
}

Future<void> _selectReason(WidgetTester tester, ReportReason reason) async {
  await tester.tap(find.text(reason.label));
  await tester.pump();
}

Future<void> _tapSubmit(WidgetTester tester) async {
  await tester.tap(find.text('Gửi báo cáo'));
  await tester.pump();
}

void main() {
  testWidgets('hiển thị sản phẩm và đủ 8 lý do', (tester) async {
    await _pumpForm(tester, FakeReportRepository(seed: false));

    expect(find.text('Bạn đang báo cáo'), findsOneWidget);
    expect(find.text('Xe đạp Giant cũ'), findsOneWidget);
    expect(find.text('1.200.000 ₫'), findsOneWidget);
    expect(ReportReason.values, hasLength(8));
    for (final reason in ReportReason.values) {
      expect(find.text(reason.label), findsOneWidget, reason: reason.code);
    }
    expect(find.byType(RadioListTile<ReportReason>), findsNWidgets(8));
    expect(find.text('0/500'), findsOneWidget);
    expect(find.text('Gửi báo cáo'), findsOneWidget);
  });

  testWidgets('bộ đếm ký tự cập nhật theo mô tả', (tester) async {
    await _pumpForm(tester, FakeReportRepository(seed: false));

    await tester.enterText(find.byType(TextField), 'Ảnh không khớp');
    await tester.pump();

    expect(find.text('14/500'), findsOneWidget);
  });

  testWidgets('chỉ chọn được một lý do', (tester) async {
    await _pumpForm(tester, FakeReportRepository(seed: false));

    await _selectReason(tester, ReportReason.scam);
    await _selectReason(tester, ReportReason.spam);

    final tiles = tester
        .widgetList<RadioListTile<ReportReason>>(
            find.byType(RadioListTile<ReportReason>))
        .toList();
    expect(tiles, hasLength(8));
    final group = tester.widget<RadioGroup<ReportReason>>(
        find.byType(RadioGroup<ReportReason>));
    expect(group.groupValue, ReportReason.spam);
  });

  testWidgets('thiếu lý do báo lỗi và không gọi repository', (tester) async {
    final repo = FakeReportRepository(seed: false);
    await _pumpForm(tester, repo);

    await _tapSubmit(tester);

    expect(find.text('Vui lòng chọn lý do báo cáo.'), findsOneWidget);
    expect(repo.createCalls, 0);
  });

  testWidgets('lý do Khác với mô tả ngắn báo lỗi dưới ô mô tả', (tester) async {
    final repo = FakeReportRepository(seed: false);
    await _pumpForm(tester, repo);

    await _selectReason(tester, ReportReason.other);
    await tester.enterText(find.byType(TextField), 'Ngắn quá');
    await _tapSubmit(tester);

    expect(find.text('Vui lòng mô tả thêm (tối thiểu 10 ký tự).'),
        findsOneWidget);
    expect(repo.createCalls, 0);
    // Input được giữ nguyên.
    expect(find.text('Ngắn quá'), findsOneWidget);
  });

  testWidgets('lý do khác OTHER không cần mô tả', (tester) async {
    final repo = FakeReportRepository(seed: false);
    await _pumpForm(tester, repo);

    await _selectReason(tester, ReportReason.fake);
    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(repo.createCalls, 1);
    expect(repo.lastReason, ReportReason.fake);
    expect(repo.lastDescription, isNull);
  });

  testWidgets('gửi thành công chuyển sang màn "Đã gửi báo cáo"', (tester) async {
    final repo = FakeReportRepository(seed: false);
    await _pumpForm(tester, repo);

    await _selectReason(tester, ReportReason.misleading);
    await tester.enterText(find.byType(TextField), '  Ảnh không khớp  ');
    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(repo.createCalls, 1);
    expect(repo.lastProductId, 'prd_fresh');
    expect(repo.lastReason, ReportReason.misleading);
    expect(repo.lastDescription, 'Ảnh không khớp');
    expect(find.text('Đã gửi báo cáo'), findsOneWidget);
    expect(find.text(kMsgReportThanks), findsOneWidget);
    expect(find.text('Xem báo cáo của tôi'), findsOneWidget);
    expect(find.text('Xong'), findsOneWidget);
    expect(find.byType(ReportFormPage), findsNothing);
  });

  testWidgets('"Xem báo cáo của tôi" mở danh sách có báo cáo vừa gửi',
      (tester) async {
    final repo = FakeReportRepository(seed: false);
    await _pumpForm(tester, repo);

    await _selectReason(tester, ReportReason.spam);
    await _tapSubmit(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xem báo cáo của tôi'));
    await tester.pumpAndSettle();

    expect(find.text('Báo cáo của tôi'), findsOneWidget);
    expect(find.text('Lý do: Spam, đăng trùng lặp'), findsOneWidget);
    expect(find.text('Đang chờ xử lý'), findsOneWidget);
  });

  testWidgets('409 hiện thông báo và giữ nguyên input', (tester) async {
    final repo = FakeReportRepository(seed: false)..forceAlreadyPending = true;
    await _pumpForm(tester, repo);

    await _selectReason(tester, ReportReason.scam);
    await tester.enterText(find.byType(TextField), 'Nghi lừa đảo');
    await _tapSubmit(tester);
    await tester.pump();

    expect(find.text(kMsgAlreadyReported), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Nghi lừa đảo'), findsOneWidget);
    final group = tester.widget<RadioGroup<ReportReason>>(
        find.byType(RadioGroup<ReportReason>));
    expect(group.groupValue, ReportReason.scam);
    // Nút mở lại sau lỗi.
    expect(find.text('Gửi báo cáo'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 10));
  });

  testWidgets('409 thật từ báo cáo đang chờ của sản phẩm mẫu', (tester) async {
    final repo = FakeReportRepository(); // seed: prd_01JPRODUCT1 đang PENDING
    await _pumpForm(tester, repo, args: ReportFormArgs.sample);

    await _selectReason(tester, ReportReason.misleading);
    await _tapSubmit(tester);
    await tester.pump();

    expect(find.text(kMsgAlreadyReported), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 10));
  });

  testWidgets('429 hiện thông báo quá nhiều báo cáo', (tester) async {
    final repo = FakeReportRepository(seed: false)..forceRateLimited = true;
    await _pumpForm(tester, repo);

    await _selectReason(tester, ReportReason.spam);
    await _tapSubmit(tester);
    await tester.pump();

    expect(find.text(kMsgReportRateLimited), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 10));
  });

  testWidgets('offline hiện thông báo mất mạng và cho gửi lại', (tester) async {
    final repo = FakeReportRepository(seed: false);
    repo.faults.offline = true;
    await _pumpForm(tester, repo);

    await _selectReason(tester, ReportReason.spam);
    await _tapSubmit(tester);
    await tester.pump();

    expect(find.text(kMsgOffline), findsOneWidget);

    // Có mạng lại: gửi lại với cùng input thì thành công.
    repo.faults.offline = false;
    await tester.pumpAndSettle(const Duration(seconds: 10));
    await _tapSubmit(tester);
    await tester.pumpAndSettle();
    expect(find.text('Đã gửi báo cáo'), findsOneWidget);
  });

  testWidgets('nút khoá và đổi nhãn khi đang gửi, không gửi trùng',
      (tester) async {
    final gate = Completer<void>();
    final repo = FakeReportRepository(seed: false)..gate = gate;
    await _pumpForm(tester, repo);

    await _selectReason(tester, ReportReason.scam);
    await _tapSubmit(tester);
    await tester.pump();

    expect(find.text('Đang gửi…'), findsOneWidget);
    expect(find.text('Gửi báo cáo'), findsNothing);
    final button = tester.widget<FilledButton>(find.ancestor(
      of: find.text('Đang gửi…'),
      matching: find.byType(FilledButton),
    ));
    expect(button.onPressed, isNull);

    await tester.tap(find.text('Đang gửi…'), warnIfMissed: false);
    await tester.pump();
    expect(repo.createCalls, 1);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Đã gửi báo cáo'), findsOneWidget);
    expect(repo.createCalls, 1);
  });

  testWidgets('route form không có arguments dùng sản phẩm mẫu',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      initialRoute: kReportFormRoute,
      routes: reportRoutes(repository: FakeReportRepository(seed: false)),
    ));

    expect(find.text('Giáo trình Giải tích 1'), findsOneWidget);
    expect(find.text('45.000 ₫'), findsOneWidget);
  });
}
