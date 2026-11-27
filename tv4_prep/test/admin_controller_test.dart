import 'package:test/test.dart';
import 'package:tv4_prep/tv4_prep.dart';

const String _sample = 'rpt_01JREPORT1';
const String _validNote = 'Da kiem tra snapshot va thong tin hien tai.';

AdminController makeController(
  FakeAdminRepository repo, {
  ReportStatus? initialFilter = ReportStatus.pending,
  int pageSize = 20,
}) {
  final c = AdminController(
    repository: repo,
    initialFilter: initialFilter,
    pageSize: pageSize,
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('danh sách', () {
    test('tải hàng đợi PENDING từ dữ liệu mẫu', () async {
      final repo = FakeAdminRepository();
      final c = makeController(repo);

      await c.loadReports();

      expect(c.state.items.map((i) => i.id), [_sample]);
      expect(c.state.items.single.status, ReportStatus.pending);
      expect(c.state.totalItems, 1);
      expect(c.state.hasMore, isFalse);
      expect(c.state.loadingList, isFalse);
      expect(c.state.error, isNull);
    });

    test('phân trang: loadMore nối thêm trang sau cho tới khi hết', () async {
      final repo = FakeAdminRepository(seed: false)..seedReports(25);
      final c = makeController(repo, pageSize: 10);

      await c.loadReports();
      expect(c.state.items, hasLength(10));
      expect(c.state.hasMore, isTrue);
      expect(c.state.totalItems, 25);

      await c.loadMore();
      expect(c.state.items, hasLength(20));
      expect(c.state.page, 2);

      await c.loadMore();
      expect(c.state.items, hasLength(25));
      expect(c.state.hasMore, isFalse);

      await c.loadMore(); // hết: không làm gì
      expect(c.state.items, hasLength(25));
      expect(c.state.items.map((i) => i.id).toSet(), hasLength(25));
    });

    test('lọc theo status và đặt lại từ trang 1', () async {
      final repo = FakeAdminRepository()
        ..addReport(id: 'rpt_done', status: ReportStatus.resolved)
        ..addReport(id: 'rpt_rej', status: ReportStatus.rejected);
      final c = makeController(repo);

      await c.loadReports();
      expect(c.state.items.map((i) => i.id), [_sample]);

      await c.setFilter(ReportStatus.resolved);
      expect(c.state.statusFilter, ReportStatus.resolved);
      expect(c.state.items.map((i) => i.id), ['rpt_done']);

      await c.setFilter(null);
      expect(c.state.statusFilter, isNull);
      expect(c.state.items, hasLength(3));
    });

    test('offline: thông báo tiếng Việt, thử lại được', () async {
      final repo = FakeAdminRepository();
      repo.faults.offline = true;
      final c = makeController(repo);

      await c.loadReports();
      expect(c.state.error, kMsgOffline);
      expect(c.state.loadingList, isFalse);
      expect(c.state.accessDenied, isFalse);

      repo.faults.offline = false;
      await c.loadReports();
      expect(c.state.error, isNull);
      expect(c.state.items, hasLength(1));
    });

    test('403 ADMIN_REQUIRED: accessDenied và không lặp request', () async {
      final repo = FakeAdminRepository()..isAdmin = false;
      final c = makeController(repo);

      await c.loadReports();

      expect(c.state.accessDenied, isTrue);
      expect(c.state.error, kMsgForbidden);
      expect(c.state.items, isEmpty);

      // Dù sau đó server cho phép, controller không tự gọi lại.
      repo.isAdmin = true;
      await c.loadReports();
      await c.openDetail(_sample);
      expect(c.state.items, isEmpty);
      expect(c.state.detail, isNull);
    });
  });

  group('chi tiết', () {
    test('mở chi tiết: snapshot và canResolve', () async {
      final repo = FakeAdminRepository();
      final c = makeController(repo);

      await c.openDetail(_sample);

      final d = c.state.detail!;
      expect(d.id, _sample);
      expect(d.snapshotTitle, 'Giao trinh Giai tich 1');
      expect(d.snapshotPriceVnd, 45000);
      expect(d.canResolve, isTrue);
      expect(c.state.loadingDetail, isFalse);

      c.closeDetail();
      expect(c.state.detail, isNull);
    });

    test('không tìm thấy report: lỗi, không có detail', () async {
      final repo = FakeAdminRepository();
      final c = makeController(repo);

      await c.openDetail('rpt_khong_co');

      expect(c.state.detail, isNull);
      expect(c.state.error, isNotNull);
      expect(c.state.loadingDetail, isFalse);
    });
  });

  group('resolve', () {
    test('ghi chú ngắn bị chặn, không gọi API', () async {
      final repo = FakeAdminRepository();
      final c = makeController(repo);
      await c.openDetail(_sample);

      final ok = await c.resolve(AdminAction.removeProduct, 'abc');

      expect(ok, isFalse);
      expect(c.state.error, validateAdminNote('abc'));
      expect(repo.resolveCalls, 0);
    });

    test('không có detail: không làm gì', () async {
      final repo = FakeAdminRepository();
      final c = makeController(repo);

      expect(await c.resolve(AdminAction.removeProduct, _validNote), isFalse);
      expect(repo.resolveCalls, 0);
    });

    test('thành công: detail đổi trạng thái, dòng rời khỏi hàng đợi PENDING',
        () async {
      final repo = FakeAdminRepository();
      final c = makeController(repo);
      await c.loadReports();
      await c.openDetail(_sample);

      final ok = await c.resolve(
        AdminAction.removeProductAndBanOwner,
        '  $_validNote  ',
      );

      expect(ok, isTrue);
      expect(repo.resolveCalls, 1);
      expect(repo.lastAction, AdminAction.removeProductAndBanOwner);
      expect(repo.lastNote, _validNote); // đã trim
      expect(c.state.detail!.status, ReportStatus.resolved);
      expect(c.state.detail!.canResolve, isFalse);
      expect(c.state.notice, kMsgAdminResolved);
      expect(c.state.resolving, isFalse);
      expect(c.state.error, isNull);
      expect(c.state.items, isEmpty);
      expect(c.state.totalItems, 0);
    });

    test('REJECT_REPORT => REJECTED; lọc "tất cả" giữ dòng và đổi status',
        () async {
      final repo = FakeAdminRepository();
      final c = makeController(repo, initialFilter: null);
      await c.loadReports();
      await c.openDetail(_sample);

      expect(await c.resolve(AdminAction.rejectReport, _validNote), isTrue);

      expect(c.state.detail!.status, ReportStatus.rejected);
      expect(c.state.items.single.status, ReportStatus.rejected);
    });

    test('đã xử lý rồi thì không cho xử lý lại (không gọi API)', () async {
      final repo = FakeAdminRepository()
        ..addReport(id: 'rpt_done', status: ReportStatus.resolved);
      final c = makeController(repo);
      await c.openDetail('rpt_done');

      expect(c.state.detail!.canResolve, isFalse);
      final ok = await c.resolve(AdminAction.removeProduct, _validNote);

      expect(ok, isFalse);
      expect(c.state.error, kMsgReportAlreadyResolved);
      expect(repo.resolveCalls, 0);
    });

    test('409 REPORT_ALREADY_RESOLVED: báo đã xử lý và tải lại chi tiết',
        () async {
      final repo = FakeAdminRepository();
      final c = makeController(repo);
      await c.loadReports();
      await c.openDetail(_sample);
      expect(c.state.detail!.canResolve, isTrue);

      // Admin khác xử lý ngay trước khi mình bấm.
      repo.markResolvedElsewhere(_sample);
      final ok = await c.resolve(AdminAction.removeProduct, _validNote);

      expect(ok, isFalse);
      expect(repo.resolveCalls, 1);
      expect(c.state.error, kMsgReportAlreadyResolved);
      expect(c.state.detail!.status, ReportStatus.resolved);
      expect(c.state.detail!.canResolve, isFalse);
      expect(c.state.resolving, isFalse);
      expect(c.state.items, isEmpty); // dòng rời hàng đợi PENDING
    });

    test('403 ADMIN_REQUIRED khi resolve: accessDenied, không lặp request',
        () async {
      final repo = FakeAdminRepository();
      final c = makeController(repo);
      await c.openDetail(_sample);

      repo.isAdmin = false;
      final ok = await c.resolve(AdminAction.removeProduct, _validNote);

      expect(ok, isFalse);
      expect(c.state.accessDenied, isTrue);
      expect(c.state.error, kMsgForbidden);
      expect(c.state.resolving, isFalse);
      expect(repo.resolveCalls, 1);

      repo.isAdmin = true;
      expect(await c.resolve(AdminAction.removeProduct, _validNote), isFalse);
      expect(repo.resolveCalls, 1); // không gọi lại
    });

    test('offline: giữ nguyên detail để thử lại', () async {
      final repo = FakeAdminRepository();
      final c = makeController(repo);
      await c.openDetail(_sample);

      repo.faults.offline = true;
      expect(await c.resolve(AdminAction.removeProduct, _validNote), isFalse);
      expect(c.state.error, kMsgOffline);
      expect(c.state.detail!.canResolve, isTrue);
      expect(c.state.accessDenied, isFalse);

      repo.faults.offline = false;
      expect(await c.resolve(AdminAction.removeProduct, _validNote), isTrue);
    });
  });

  group('ban user', () {
    test('lý do ngắn bị chặn; hợp lệ thì khóa được', () async {
      final repo = FakeAdminRepository();
      final c = makeController(repo);

      expect(await c.banUser('usr_01JABC123', 'ngan'), isFalse);
      expect(c.state.error, validateAdminNote('ngan'));
      expect(repo.bannedUserIds, isEmpty);

      expect(
        await c.banUser('usr_01JABC123', 'Tai khoan vi pham lap lai.'),
        isTrue,
      );
      expect(repo.bannedUserIds, ['usr_01JABC123']);
      expect(c.state.notice, kMsgAdminBanned);
    });

    test('Admin không tự khóa chính mình (409)', () async {
      final repo = FakeAdminRepository();
      final c = makeController(repo);

      final ok = await c.banUser(repo.adminUserId, 'Thu khoa chinh minh.');

      expect(ok, isFalse);
      expect(c.state.error, isNotNull);
      expect(repo.bannedUserIds, isEmpty);
    });
  });
}
