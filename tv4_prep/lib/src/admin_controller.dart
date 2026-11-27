/// Điều khiển màn Admin: hàng đợi report, chi tiết, xử lý, khóa user (thuần Dart).
/// Tham chiếu: FR-ADMIN-02..05, AC-ADMIN-01/03/05, E-05, E-15, E-16.
library;

import 'dart:async';

import 'api_error.dart';
import 'constants.dart';
import 'enums.dart';
import 'models.dart';
import 'repositories.dart';
import 'validators.dart';

const String kMsgAdminResolved = 'Đã xử lý báo cáo.';
const String kMsgAdminBanned = 'Đã khóa tài khoản.';

const Object _unset = Object();

class AdminState {
  const AdminState({
    this.statusFilter = ReportStatus.pending,
    this.items = const <AdminReportItem>[],
    this.page = 0,
    this.hasMore = false,
    this.totalItems = 0,
    this.loadingList = false,
    this.detail,
    this.loadingDetail = false,
    this.resolving = false,
    this.accessDenied = false,
    this.error,
    this.notice,
  });

  /// Bộ lọc trạng thái; null = tất cả.
  final ReportStatus? statusFilter;
  final List<AdminReportItem> items;

  /// Trang đã tải gần nhất (0 = chưa tải).
  final int page;
  final bool hasMore;
  final int totalItems;
  final bool loadingList;

  final AdminReportDetail? detail;
  final bool loadingDetail;

  /// Đang gọi resolve / ban (khóa nút, chống gửi trùng).
  final bool resolving;

  /// Server trả 403: không đủ quyền Admin. Controller ngừng gọi API (E-05).
  final bool accessDenied;

  /// Lỗi tiếng Việt gần nhất.
  final String? error;

  /// Thông báo thành công gần nhất.
  final String? notice;

  AdminState copyWith({
    Object? statusFilter = _unset,
    List<AdminReportItem>? items,
    int? page,
    bool? hasMore,
    int? totalItems,
    bool? loadingList,
    Object? detail = _unset,
    bool? loadingDetail,
    bool? resolving,
    bool? accessDenied,
    Object? error = _unset,
    Object? notice = _unset,
  }) =>
      AdminState(
        statusFilter: identical(statusFilter, _unset)
            ? this.statusFilter
            : statusFilter as ReportStatus?,
        items: items ?? this.items,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        totalItems: totalItems ?? this.totalItems,
        loadingList: loadingList ?? this.loadingList,
        detail: identical(detail, _unset)
            ? this.detail
            : detail as AdminReportDetail?,
        loadingDetail: loadingDetail ?? this.loadingDetail,
        resolving: resolving ?? this.resolving,
        accessDenied: accessDenied ?? this.accessDenied,
        error: identical(error, _unset) ? this.error : error as String?,
        notice: identical(notice, _unset) ? this.notice : notice as String?,
      );
}

class AdminController {
  /// [initialFilter] mặc định PENDING (hàng đợi cần xử lý); truyền null = tất cả.
  AdminController({
    required this.repository,
    ReportStatus? initialFilter = ReportStatus.pending,
    this.pageSize = 20,
  }) : _state = AdminState(statusFilter: initialFilter);

  final AdminRepository repository;
  final int pageSize;

  final StreamController<AdminState> _states =
      StreamController<AdminState>.broadcast();
  AdminState _state;
  bool _closed = false;
  bool _busy = false; // khóa resolve / ban
  int _listToken = 0; // bỏ qua response cũ khi đổi filter / refresh
  int _detailToken = 0;

  Stream<AdminState> get states => _states.stream;
  AdminState get state => _state;

  // ---------------------------------------------------------------------
  // Danh sách
  // ---------------------------------------------------------------------

  /// Tải lại từ trang 1 với bộ lọc hiện tại.
  Future<void> loadReports() => _loadPage(1);

  /// Đổi bộ lọc trạng thái (null = tất cả) và tải lại từ trang 1.
  Future<void> setFilter(ReportStatus? status) {
    if (_closed) return Future<void>.value();
    _emit(_state.copyWith(
      statusFilter: status,
      items: const <AdminReportItem>[],
      page: 0,
      hasMore: false,
      totalItems: 0,
    ));
    return _loadPage(1);
  }

  /// Tải trang kế tiếp (nếu còn).
  Future<void> loadMore() async {
    if (_state.loadingList || !_state.hasMore) return;
    await _loadPage(_state.page + 1);
  }

  Future<void> _loadPage(int page) async {
    if (_closed || _state.accessDenied) return;
    final token = ++_listToken;
    final filter = _state.statusFilter;
    _emit(_state.copyWith(loadingList: true, error: null));
    try {
      final result =
          await repository.listReports(filter, page, pageSize: pageSize);
      if (_closed || token != _listToken) return;
      _emit(_state.copyWith(
        items: page == 1 ? result.items : [..._state.items, ...result.items],
        page: page,
        hasMore: result.hasMore,
        totalItems: result.totalItems,
        loadingList: false,
      ));
    } catch (e) {
      if (_closed || token != _listToken) return;
      _fail(e, loadingList: false);
    }
  }

  // ---------------------------------------------------------------------
  // Chi tiết
  // ---------------------------------------------------------------------

  Future<void> openDetail(String id) async {
    if (_closed || _state.accessDenied) return;
    final token = ++_detailToken;
    _emit(_state.copyWith(
      loadingDetail: true,
      detail: null,
      error: null,
      notice: null,
    ));
    try {
      final detail = await repository.reportDetail(id);
      if (_closed || token != _detailToken) return;
      _emit(_state.copyWith(detail: detail, loadingDetail: false));
    } catch (e) {
      if (_closed || token != _detailToken) return;
      _fail(e, loadingDetail: false);
    }
  }

  void closeDetail() {
    if (_closed) return;
    _detailToken++;
    _emit(_state.copyWith(
      detail: null,
      loadingDetail: false,
      error: null,
      notice: null,
    ));
  }

  // ---------------------------------------------------------------------
  // Xử lý
  // ---------------------------------------------------------------------

  /// Xử lý report đang mở. Trả true nếu server chấp nhận.
  /// - Chỉ cho khi `detail.canResolve` (E-15/E-16).
  /// - Ghi chú tối thiểu 5 ký tự (`validateAdminNote`).
  /// - 409 REPORT_ALREADY_RESOLVED: báo "đã được xử lý" và tải lại chi tiết.
  /// - 403: đặt `accessDenied`, không lặp request.
  Future<bool> resolve(AdminAction action, String? note) async {
    if (_closed || _busy || _state.accessDenied) return false;
    final detail = _state.detail;
    if (detail == null) return false;
    if (!detail.canResolve) {
      _emit(_state.copyWith(error: kMsgReportAlreadyResolved, notice: null));
      return false;
    }
    final invalid = validateAdminNote(note);
    if (invalid != null) {
      _emit(_state.copyWith(error: invalid, notice: null));
      return false;
    }

    _busy = true;
    _emit(_state.copyWith(resolving: true, error: null, notice: null));
    try {
      final result =
          await repository.resolve(detail.id, action, (note ?? '').trim());
      if (_closed) return false;
      final newStatus = result.reportStatus != ReportStatus.unknown
          ? result.reportStatus
          : (action == AdminAction.rejectReport
              ? ReportStatus.rejected
              : ReportStatus.resolved);
      final current = _state.detail;
      var next = _state.copyWith(
        resolving: false,
        notice: kMsgAdminResolved,
        detail: current != null && current.id == detail.id
            ? current.withStatus(newStatus)
            : current,
      );
      next = _listWithStatus(next, detail.id, newStatus);
      _emit(next);
      return true;
    } on ApiException catch (e) {
      if (_closed) return false;
      if (e.code == 'REPORT_ALREADY_RESOLVED') {
        _emit(_state.copyWith(resolving: false, error: e.message));
        await _refreshAfterConflict(detail.id);
      } else {
        _fail(e, resolving: false);
      }
      return false;
    } catch (e) {
      if (_closed) return false;
      _fail(e, resolving: false);
      return false;
    } finally {
      _busy = false;
    }
  }

  /// Khóa tài khoản (API-ADMIN-04). [reason] tối thiểu 5 ký tự.
  Future<bool> banUser(String userId, String? reason) async {
    if (_closed || _busy || _state.accessDenied) return false;
    final invalid = validateAdminNote(reason);
    if (invalid != null) {
      _emit(_state.copyWith(error: invalid, notice: null));
      return false;
    }
    _busy = true;
    _emit(_state.copyWith(resolving: true, error: null, notice: null));
    try {
      await repository.banUser(userId, (reason ?? '').trim());
      if (_closed) return false;
      _emit(_state.copyWith(resolving: false, notice: kMsgAdminBanned));
      return true;
    } catch (e) {
      if (_closed) return false;
      _fail(e, resolving: false);
      return false;
    } finally {
      _busy = false;
    }
  }

  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    await _states.close();
  }

  // ---------------------------------------------------------------------
  // Nội bộ
  // ---------------------------------------------------------------------

  /// Sau 409: tải lại chi tiết để hiển thị trạng thái mới nhất, cập nhật dòng
  /// tương ứng trong danh sách. Thất bại thì giữ nguyên thông báo lỗi 409.
  Future<void> _refreshAfterConflict(String id) async {
    try {
      final fresh = await repository.reportDetail(id);
      if (_closed) return;
      final current = _state.detail;
      var next = current != null && current.id == id
          ? _state.copyWith(detail: fresh)
          : _state;
      next = _listWithStatus(next, id, fresh.status);
      _emit(next);
    } catch (_) {
      // Giữ thông báo "đã được xử lý"; người dùng có thể mở lại chi tiết.
    }
  }

  /// Cập nhật trạng thái của một dòng trong danh sách; nếu không còn khớp bộ
  /// lọc hiện tại thì bỏ dòng đó khỏi danh sách.
  AdminState _listWithStatus(AdminState s, String id, ReportStatus status) {
    final idx = s.items.indexWhere((i) => i.id == id);
    if (idx < 0) return s;
    final filter = s.statusFilter;
    final items = [...s.items];
    if (filter != null && filter != status) {
      items.removeAt(idx);
      return s.copyWith(
        items: items,
        totalItems: s.totalItems > 0 ? s.totalItems - 1 : 0,
      );
    }
    items[idx] = items[idx].withStatus(status);
    return s.copyWith(items: items);
  }

  /// Ghi lỗi vào state; các cờ loading truyền vào được tắt, null = giữ nguyên.
  void _fail(
    Object e, {
    bool? loadingList,
    bool? loadingDetail,
    bool? resolving,
  }) {
    final denied = e is ApiException && e.isForbidden;
    _emit(_state.copyWith(
      loadingList: loadingList,
      loadingDetail: loadingDetail,
      resolving: resolving,
      accessDenied: denied ? true : null,
      error: errorMessageOf(e),
      notice: null,
    ));
  }

  void _emit(AdminState next) {
    if (_closed) return;
    _state = next;
    _states.add(next);
  }
}
