/// Validate phía client (server vẫn là nơi quyết định cuối cùng).
/// Mỗi hàm trả về `null` nếu hợp lệ, hoặc thông báo lỗi tiếng Việt.
library;

import 'constants.dart';
import 'enums.dart';

String? validateMessageText(String? raw) {
  final t = (raw ?? '').trim();
  if (t.isEmpty) return 'Tin nhắn không được để trống.';
  if (t.length > kMessageMaxLength) {
    return 'Tin nhắn tối đa $kMessageMaxLength ký tự.';
  }
  return null;
}

String? validateReport({required ReportReason? reason, String? description}) {
  if (reason == null) return 'Vui lòng chọn lý do báo cáo.';
  final d = (description ?? '').trim();
  if (d.length > kReportDescriptionMaxLength) {
    return 'Mô tả tối đa $kReportDescriptionMaxLength ký tự.';
  }
  if (reason == ReportReason.other && d.length < kReportOtherMinLength) {
    return 'Vui lòng mô tả thêm (tối thiểu $kReportOtherMinLength ký tự).';
  }
  return null;
}

/// Ghi chú xử lý của Admin / lý do khóa tài khoản.
String? validateAdminNote(String? raw) {
  final t = (raw ?? '').trim();
  if (t.length < kAdminNoteMinLength) {
    return 'Ghi chú tối thiểu $kAdminNoteMinLength ký tự.';
  }
  return null;
}
