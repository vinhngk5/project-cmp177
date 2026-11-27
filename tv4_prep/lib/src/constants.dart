/// Hằng số dùng chung cho chat / report / admin.
/// Nguồn: docs/SRS.md phụ lục B, C, E, F và các mục 4.6, 4.9, 4.10.
library;

// ---- Giới hạn validate ----
const int kMessageMaxLength = 1000; // FR-CHAT, AC-CHAT-04
const int kHistoryDefaultLimit = 30; // API-CHAT-03
const int kHistoryMaxLimit = 100;
const int kReportDescriptionMaxLength = 500; // API-REPORT-01
const int kReportOtherMinLength = 10; // reason == OTHER
const int kAdminNoteMinLength = 5; // API-ADMIN-03/04
const int kReportDailyLimit = 10; // OQ-13

// ---- Quick reply (Phụ lục B) ----
const List<String> kBuyerQuickReplies = [
  'Món này còn không bạn?',
  'Giá có thương lượng được không?',
  'Mình có thể xem trực tiếp ở đâu?',
  'Món này còn bảo hành / có lỗi gì không?',
  'Mình lấy được hôm nay không?',
];

const List<String> kSellerQuickReplies = [
  'Món này vẫn còn bạn nhé.',
  'Giá này mình để hợp lý rồi bạn ạ.',
  'Bạn có thể xem ở [khu vực] nhé.',
  'Bạn tiện gặp lúc nào?',
  'Xin lỗi, món này đã có người hỏi trước.',
];

// ---- Mẹo giao dịch an toàn (Phụ lục F) ----
const List<String> kSafetyTips = [
  'Hẹn gặp ở nơi công cộng, đông người: căn tin, thư viện, sảnh ký túc xá.',
  'Kiểm tra hàng kỹ trước khi trả tiền; với đồ điện tử thì bật lên dùng thử.',
  'Không chuyển khoản trước khi chưa nhận hàng.',
  'Không chia sẻ mã OTP, mật khẩu hay thông tin thẻ ngân hàng.',
  'Trao đổi qua chat trong app để có lịch sử khi cần báo cáo.',
  'Gặp dấu hiệu lừa đảo → dùng Báo cáo ngay trong app.',
];

// ---- Thông báo chuẩn (Phụ lục E) ----
const String kMsgOffline = 'Không có kết nối mạng. Vui lòng thử lại.'; // MSG-03
const String kMsgForbidden = 'Bạn không có quyền thực hiện thao tác này.'; // MSG-04
const String kMsgProductGone = 'Tin không còn tồn tại hoặc đã bị gỡ.'; // MSG-05
const String kMsgAlreadyReported =
    'Bạn đã báo cáo nội dung này, đang chờ xử lý.'; // MSG-07
const String kMsgReportThanks =
    'Cảm ơn bạn. Chúng tôi sẽ xem xét trong thời gian sớm nhất.'; // MSG-08
const String kMsgGeneric = 'Đã có lỗi xảy ra. Vui lòng thử lại.'; // MSG-09
const String kMsgSessionExpired =
    'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'; // MSG-10
const String kMsgProductUnavailable =
    'Tin đã được bán hoặc không còn khả dụng.'; // MSG-11
const String kMsgReportRateLimited =
    'Bạn đã gửi quá nhiều báo cáo hôm nay. Vui lòng thử lại sau.';
const String kMsgReportAlreadyResolved = 'Báo cáo này đã được xử lý.'; // E-15
const String kMsgChatReadOnly = 'Cuộc trò chuyện này chỉ còn có thể đọc.';
