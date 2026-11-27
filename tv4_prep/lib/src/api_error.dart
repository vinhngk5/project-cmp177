/// Lỗi API dùng chung cho chat / report / admin (docs/API.md mục 1.2, 5, 6.10).
///
/// [ApiException.message] luôn là thông báo tiếng Việt thân thiện lấy từ
/// `messageForError`; không bao giờ chứa nội dung kỹ thuật của server
/// (AC-ERR-01). Chuỗi `message` do server gửi trong envelope bị bỏ qua.
library;

import 'dart:convert';

import 'chat_utils.dart';
import 'constants.dart';

/// Mã nội bộ cho lỗi không nhận được response (mất mạng, timeout).
const String kErrorCodeNetwork = 'NETWORK_OFFLINE';

/// `httpStatus` dùng cho lỗi mạng (không có HTTP response).
const int kHttpStatusNetwork = 0;

/// Một số mã lỗi có hai tên trong tài liệu (API.md mục 4.9 so với mục 5).
/// Chuẩn hóa về tên ở mục 4.9 để `messageForError` và controller so sánh một lần.
String? normalizeErrorCode(String? code) {
  switch (code) {
    case 'DUPLICATE_PENDING_REPORT':
      return 'REPORT_ALREADY_PENDING';
    default:
      return code;
  }
}

/// Đọc header `Retry-After` dạng số giây. Dạng HTTP-date không hỗ trợ (trả null).
Duration? parseRetryAfter(String? header) {
  if (header == null) return null;
  final seconds = int.tryParse(header.trim());
  if (seconds == null || seconds < 0) return null;
  return Duration(seconds: seconds);
}

class ApiException implements Exception {
  /// [message] mặc định lấy từ `messageForError(code, httpStatus)`.
  factory ApiException({
    required int httpStatus,
    String? code,
    String? message,
    Duration? retryAfter,
    String? requestId,
  }) {
    final normalized = normalizeErrorCode(code);
    return ApiException._(
      httpStatus: httpStatus,
      code: normalized,
      message: message ??
          messageForError(code: normalized, httpStatus: httpStatus),
      retryAfter: retryAfter,
      requestId: requestId,
    );
  }

  const ApiException._({
    required this.httpStatus,
    required this.code,
    required this.message,
    required this.retryAfter,
    required this.requestId,
  });

  /// Không có kết nối / timeout (E-01, E-02).
  factory ApiException.network() => const ApiException._(
        httpStatus: kHttpStatusNetwork,
        code: kErrorCodeNetwork,
        message: kMsgOffline,
        retryAfter: null,
        requestId: null,
      );

  /// Tạo từ JSON đã decode của error envelope:
  /// `{"error": {"code": ..., "message": ..., "details": [...]}, "meta": {...}}`.
  /// Body sai định dạng vẫn cho ra exception hợp lệ (chỉ còn httpStatus).
  factory ApiException.fromEnvelope(
    int httpStatus,
    Object? body, {
    Duration? retryAfter,
  }) {
    String? code;
    String? requestId;
    if (body is Map) {
      final err = body['error'];
      if (err is Map) {
        final c = err['code'];
        if (c is String) code = c;
      }
      final meta = body['meta'];
      if (meta is Map) {
        final r = meta['request_id'];
        if (r is String) requestId = r;
      }
    }
    return ApiException(
      httpStatus: httpStatus,
      code: code,
      retryAfter: retryAfter,
      requestId: requestId,
    );
  }

  /// Tạo từ response thô: [rawBody] là chuỗi JSON (có thể rỗng / không phải JSON),
  /// [retryAfterHeader] là giá trị header `Retry-After` nếu có.
  factory ApiException.fromResponse(
    int httpStatus,
    String? rawBody, {
    String? retryAfterHeader,
  }) {
    Object? decoded;
    if (rawBody != null && rawBody.trim().isNotEmpty) {
      try {
        decoded = jsonDecode(rawBody);
      } on FormatException {
        decoded = null;
      }
    }
    return ApiException.fromEnvelope(
      httpStatus,
      decoded,
      retryAfter: parseRetryAfter(retryAfterHeader),
    );
  }

  /// 0 nếu là lỗi mạng ([kHttpStatusNetwork]).
  final int httpStatus;

  /// Mã lỗi đã chuẩn hóa (vd REPORT_ALREADY_PENDING); có thể null.
  final String? code;

  /// Thông báo tiếng Việt để hiển thị cho người dùng.
  final String message;

  /// Thời gian nên chờ trước khi thử lại (429 + Retry-After), nếu server cung cấp.
  final Duration? retryAfter;

  /// `meta.request_id` để hỗ trợ debug (không hiển thị cho người dùng).
  final String? requestId;

  bool get isNetwork => httpStatus == kHttpStatusNetwork;
  bool get isUnauthorized => httpStatus == 401;
  bool get isForbidden => httpStatus == 403;
  bool get isNotFound => httpStatus == 404;
  bool get isConflict => httpStatus == 409;
  bool get isRateLimited => httpStatus == 429;
  bool get isServerError => httpStatus >= 500;

  @override
  String toString() => 'ApiException($httpStatus, $code)';
}

/// Thông báo hiển thị cho mọi lỗi bắt được: [ApiException] dùng message của nó,
/// lỗi khác (bug, parse...) dùng thông báo chung, không lộ chi tiết kỹ thuật.
String errorMessageOf(Object error) =>
    error is ApiException ? error.message : kMsgGeneric;
