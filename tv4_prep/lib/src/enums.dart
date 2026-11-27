/// Enum dùng chung. `fromCode` không ném lỗi: mã lạ trả về giá trị `unknown`
/// để app không crash khi server thêm giá trị mới.
library;

enum MessageType {
  text('TEXT'),
  system('SYSTEM'),
  unknown('');

  const MessageType(this.code);
  final String code;

  static MessageType fromCode(String? c) => MessageType.values
      .firstWhere((e) => e.code == c, orElse: () => MessageType.unknown);
}

/// Trạng thái gửi ở phía client (FR-CHAT-07).
enum SendStatus { pending, sent, failed }

enum ConversationStatus {
  open('OPEN'),
  readOnly('READ_ONLY');

  const ConversationStatus(this.code);
  final String code;

  /// Thiếu trường `status` thì mặc định OPEN (giả định #4 trong TV4-OPEN-QUESTIONS).
  static ConversationStatus fromCode(String? c) => ConversationStatus.values
      .firstWhere((e) => e.code == c, orElse: () => ConversationStatus.open);
}

/// Lý do báo cáo Product (Phụ lục C).
enum ReportReason {
  prohibited('PROHIBITED', 'Hàng cấm, vi phạm pháp luật'),
  scam('SCAM', 'Có dấu hiệu lừa đảo'),
  fake('FAKE', 'Hàng giả, hàng nhái'),
  misleading('MISLEADING', 'Thông tin hoặc hình ảnh sai sự thật'),
  inappropriate('INAPPROPRIATE', 'Nội dung phản cảm, xúc phạm'),
  wrongCategory('WRONG_CATEGORY', 'Sai danh mục'),
  spam('SPAM', 'Spam, đăng trùng lặp'),
  other('OTHER', 'Khác');

  const ReportReason(this.code, this.label);
  final String code;
  final String label;

  static ReportReason? fromCode(String? c) {
    for (final e in ReportReason.values) {
      if (e.code == c) return e;
    }
    return null;
  }
}

/// PENDING -> RESOLVED | REJECTED (mục 6.5).
enum ReportStatus {
  pending('PENDING'),
  resolved('RESOLVED'),
  rejected('REJECTED'),
  unknown('');

  const ReportStatus(this.code);
  final String code;

  static ReportStatus fromCode(String? c) => ReportStatus.values
      .firstWhere((e) => e.code == c, orElse: () => ReportStatus.unknown);
}

/// Hành động Admin xử lý report (API-ADMIN-03).
enum AdminAction {
  rejectReport('REJECT_REPORT', 'Không vi phạm'),
  removeProduct('REMOVE_PRODUCT', 'Gỡ tin'),
  removeProductAndBanOwner(
      'REMOVE_PRODUCT_AND_BAN_OWNER', 'Gỡ tin + khóa chủ tin');

  const AdminAction(this.code, this.label);
  final String code;
  final String label;
}
