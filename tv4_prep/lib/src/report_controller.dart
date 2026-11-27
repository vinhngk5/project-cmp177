/// Điều khiển form báo cáo Product (thuần Dart).
/// Tham chiếu: FR-REPORT-01..08, AC-REPORT-02/04/06/07, AC-ERR-03, E-10, E-11.
library;

import 'dart:async';

import 'api_error.dart';
import 'constants.dart';
import 'enums.dart';
import 'models.dart';
import 'repositories.dart';
import 'validators.dart';

enum ReportSubmitStatus { idle, submitting, success, error }

class ReportState {
  const ReportState({
    this.status = ReportSubmitStatus.idle,
    this.reason,
    this.description = '',
    this.errorMessage,
    this.errorCode,
    this.retryAfter,
    this.report,
  });

  final ReportSubmitStatus status;

  /// Input được giữ nguyên khi lỗi để form không mất dữ liệu (AC-ERR-03).
  final ReportReason? reason;
  final String description;

  /// Thông báo tiếng Việt khi `status == error`.
  final String? errorMessage;

  /// Mã lỗi server (vd REPORT_ALREADY_PENDING); null với lỗi validate / mạng.
  final String? errorCode;

  /// Thời gian chờ server yêu cầu khi bị 429 (nếu có Retry-After).
  final Duration? retryAfter;

  /// Report vừa tạo khi `status == success`.
  final MyReport? report;

  bool get isSubmitting => status == ReportSubmitStatus.submitting;
  bool get isSuccess => status == ReportSubmitStatus.success;

  /// Báo cáo trùng, đang chờ xử lý (E-10): UI hiển thị trạng thái "đang chờ".
  bool get alreadyPending => errorCode == 'REPORT_ALREADY_PENDING';
}

class ReportController {
  ReportController({required this.productId, required this.repository});

  final String productId;
  final ReportRepository repository;

  final StreamController<ReportState> _states =
      StreamController<ReportState>.broadcast();
  ReportState _state = const ReportState();
  bool _submitting = false; // khóa đồng bộ, đặt trước await đầu tiên
  bool _closed = false;

  Stream<ReportState> get states => _states.stream;
  ReportState get state => _state;

  /// Gửi báo cáo. Trả true nếu server đã nhận (201). Gọi lại khi đang gửi hoặc
  /// đã gửi thành công sẽ bị bỏ qua (không gửi trùng, AC-REPORT-06).
  Future<bool> submit(ReportReason? reason, String? description) async {
    if (_closed || _submitting || _state.isSuccess) return false;
    final rawDescription = description ?? '';

    final invalid = validateReport(reason: reason, description: description);
    if (invalid != null || reason == null) {
      _emit(ReportState(
        status: ReportSubmitStatus.error,
        reason: reason,
        description: rawDescription,
        errorMessage: invalid ?? kMsgGeneric,
      ));
      return false;
    }

    _submitting = true;
    _emit(ReportState(
      status: ReportSubmitStatus.submitting,
      reason: reason,
      description: rawDescription,
    ));
    final trimmed = rawDescription.trim();
    try {
      final created = await repository.createReport(
        productId,
        reason,
        trimmed.isEmpty ? null : trimmed,
      );
      _emit(ReportState(
        status: ReportSubmitStatus.success,
        reason: reason,
        description: rawDescription,
        report: created,
      ));
      return true;
    } on ApiException catch (e) {
      _emit(ReportState(
        status: ReportSubmitStatus.error,
        reason: reason,
        description: rawDescription,
        errorMessage: e.isRateLimited ? kMsgReportRateLimited : e.message,
        errorCode: e.code,
        retryAfter: e.retryAfter,
      ));
      return false;
    } catch (_) {
      _emit(ReportState(
        status: ReportSubmitStatus.error,
        reason: reason,
        description: rawDescription,
        errorMessage: kMsgGeneric,
      ));
      return false;
    } finally {
      _submitting = false;
    }
  }

  /// Đưa form về trạng thái ban đầu (ví dụ mở lại form sau khi thành công).
  void reset() {
    if (_closed || _submitting) return;
    _emit(const ReportState());
  }

  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    await _states.close();
  }

  void _emit(ReportState next) {
    if (_closed) return;
    _state = next;
    _states.add(next);
  }
}
