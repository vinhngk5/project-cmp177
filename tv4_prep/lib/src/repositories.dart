/// Interface tầng dữ liệu cho chat / report / admin và các model nhỏ đi kèm.
/// Cài đặt thật (HTTP + WebSocket) nằm ở app Flutter; trong gói này chỉ có
/// bản giả lập (fakes.dart). Mọi lỗi API được ném dưới dạng `ApiException`.
library;

import 'enums.dart';
import 'models.dart';

// ---------------------------------------------------------------------------
// Model nhỏ
// ---------------------------------------------------------------------------

/// Kết quả phân trang. Dùng cho cả kiểu page/page_size (list) lẫn cursor
/// (lịch sử chat). Đặt tên khác `Page` để không đụng `Page` của Flutter.
class PageResult<T> {
  const PageResult({
    required this.items,
    this.page = 1,
    this.pageSize = 0,
    this.totalItems = 0,
    this.hasMore = false,
    this.nextCursor,
  });

  final List<T> items;
  final int page;
  final int pageSize;
  final int totalItems;
  final bool hasMore;

  /// Chỉ có với phân trang theo cursor (`meta.next_cursor`).
  final String? nextCursor;

  /// Dựng từ `meta` của response envelope. Nếu server không gửi `has_more`
  /// (list dạng page/page_size) thì suy ra từ `page * page_size < total_items`.
  factory PageResult.fromMeta(List<T> items, Map<String, dynamic>? meta) {
    final m = meta ?? const <String, dynamic>{};
    final page = (m['page'] as int?) ?? 1;
    final pageSize = (m['page_size'] as int?) ?? items.length;
    final total = (m['total_items'] as int?) ?? items.length;
    final more = m['has_more'];
    return PageResult<T>(
      items: items,
      page: page,
      pageSize: pageSize,
      totalItems: total,
      hasMore: more is bool ? more : page * pageSize < total,
      nextCursor: m['next_cursor'] as String?,
    );
  }
}

/// Response `POST /conversations` (API-CHAT-02).
class ConversationRef {
  const ConversationRef({
    required this.id,
    required this.productId,
    required this.buyerId,
    required this.sellerId,
    required this.createdAt,
    required this.isNew,
  });

  final String id;
  final String productId;
  final String buyerId;
  final String sellerId;
  final DateTime createdAt;
  final bool isNew;

  factory ConversationRef.fromJson(Map<String, dynamic> j) => ConversationRef(
        id: j['id'] as String,
        productId: j['product_id'] as String,
        buyerId: j['buyer_id'] as String,
        sellerId: j['seller_id'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        isNew: (j['is_new'] as bool?) ?? false,
      );
}

/// Response `POST /conversations/{id}/read` (API.md mục 6.6).
class ReadReceipt {
  const ReadReceipt({
    required this.conversationId,
    required this.unreadCount,
    required this.lastReadAt,
  });

  final String conversationId;
  final int unreadCount;
  final DateTime lastReadAt;

  factory ReadReceipt.fromJson(Map<String, dynamic> j) => ReadReceipt(
        conversationId: j['conversation_id'] as String,
        unreadCount: (j['unread_count'] as int?) ?? 0,
        lastReadAt: DateTime.parse(j['last_read_at'] as String),
      );
}

/// `AdminAction` không có `fromCode` (enums.dart giữ nguyên) nên đặt ở đây.
AdminAction? adminActionFromCode(String? code) {
  for (final a in AdminAction.values) {
    if (a.code == code) return a;
  }
  return null;
}

/// Response `POST /admin/reports/{id}/resolve` (API-ADMIN-03).
class ResolveResult {
  const ResolveResult({
    required this.reportId,
    required this.reportStatus,
    required this.action,
    this.productStatus,
    this.ownerStatus,
    this.resolvedAt,
  });

  final String reportId;
  final ReportStatus reportStatus;
  final AdminAction? action;
  final String? productStatus;
  final String? ownerStatus;
  final DateTime? resolvedAt;

  factory ResolveResult.fromJson(Map<String, dynamic> j) => ResolveResult(
        reportId: j['report_id'] as String,
        reportStatus: ReportStatus.fromCode(j['report_status'] as String?),
        action: adminActionFromCode(j['action'] as String?),
        productStatus: j['product_status'] as String?,
        ownerStatus: j['owner_status'] as String?,
        resolvedAt: j['resolved_at'] == null
            ? null
            : DateTime.parse(j['resolved_at'] as String),
      );
}

/// Response `POST /admin/users/{id}/ban` (API-ADMIN-04).
class BanResult {
  const BanResult({
    required this.userId,
    required this.status,
    required this.banReason,
    required this.bannedAt,
  });

  final String userId;
  final String status;
  final String banReason;
  final DateTime bannedAt;

  factory BanResult.fromJson(Map<String, dynamic> j) => BanResult(
        userId: j['user_id'] as String,
        status: j['status'] as String,
        banReason: (j['ban_reason'] as String?) ?? '',
        bannedAt: DateTime.parse(j['banned_at'] as String),
      );
}

// models.dart không có copyWith cho hai model Admin; thêm tiện ích ở đây để
// controller và fake cập nhật trạng thái mà không sửa models.dart.
extension AdminReportItemStatus on AdminReportItem {
  AdminReportItem withStatus(ReportStatus newStatus) => AdminReportItem(
        id: id,
        targetType: targetType,
        targetId: targetId,
        reason: reason,
        status: newStatus,
        createdAt: createdAt,
      );
}

extension AdminReportDetailStatus on AdminReportDetail {
  AdminReportDetail withStatus(ReportStatus newStatus) => AdminReportDetail(
        id: id,
        reporterName: reporterName,
        targetId: targetId,
        targetStatus: targetStatus,
        snapshotTitle: snapshotTitle,
        snapshotPriceVnd: snapshotPriceVnd,
        snapshotCoverImageUrl: snapshotCoverImageUrl,
        reason: reason,
        description: description,
        status: newStatus,
      );
}

// ---------------------------------------------------------------------------
// WebSocket events (API.md mục 4.6)
// ---------------------------------------------------------------------------

/// Close code WebSocket (OQ-06).
const int kWsCloseUnauthenticated = 4401; // chưa xác thực / hết hạn
const int kWsCloseForbidden = 4403; // không có quyền

sealed class ChatSocketEvent {
  const ChatSocketEvent();
}

/// `message.ack`: server đã lưu tin có `client_message_id` này.
final class MessageAck extends ChatSocketEvent {
  const MessageAck({
    required this.clientMessageId,
    required this.messageId,
    required this.createdAt,
    this.status = 'SENT',
  });

  final String clientMessageId;
  final String messageId;
  final DateTime createdAt;
  final String status;
}

/// `message.new`: tin mới của người kia (hoặc tin đồng bộ).
final class MessageNew extends ChatSocketEvent {
  const MessageNew({required this.conversationId, required this.message});

  final String conversationId;
  final Message message;
}

/// Event lỗi: `{code, message, retryable}`. [conversationId] null nghĩa là lỗi
/// áp dụng cho kết nối / phòng hiện tại.
final class SocketError extends ChatSocketEvent {
  const SocketError({
    required this.code,
    required this.retryable,
    this.message,
    this.conversationId,
  });

  final String code;
  final bool retryable;
  final String? message;
  final String? conversationId;
}

/// Kết nối đóng. [closeCode] là WebSocket close code nếu biết
/// (4401 / 4403, xem [kWsCloseUnauthenticated] / [kWsCloseForbidden]).
final class Disconnected extends ChatSocketEvent {
  const Disconnected({this.closeCode});

  final int? closeCode;
}

/// Chuyển JSON đã decode của một frame server thành event. Trả null nếu frame
/// không hiểu được (event lạ hoặc thiếu trường) để lớp trên bỏ qua an toàn.
ChatSocketEvent? parseChatSocketEvent(Object? decoded) {
  if (decoded is! Map) return null;
  final name = decoded['event'];
  final rawData = decoded['data'];
  if (name is! String || rawData is! Map) return null;
  final data = Map<String, dynamic>.from(rawData);
  try {
    if (name == 'message.ack') {
      return MessageAck(
        clientMessageId: data['client_message_id'] as String,
        messageId: data['message_id'] as String,
        createdAt: DateTime.parse(data['created_at'] as String),
        status: (data['status'] as String?) ?? 'SENT',
      );
    }
    if (name == 'message.new') {
      final conversationId = data['conversation_id'] as String;
      final raw = Map<String, dynamic>.from(data['message'] as Map);
      raw['conversation_id'] = conversationId;
      return MessageNew(
        conversationId: conversationId,
        message: Message.fromJson(raw),
      );
    }
    if (name == 'error') {
      return SocketError(
        code: (data['code'] as String?) ?? 'UNKNOWN',
        // Thiếu `retryable` thì coi là retry được để không khóa phòng nhầm.
        retryable: (data['retryable'] as bool?) ?? true,
        message: data['message'] as String?,
        conversationId: data['conversation_id'] as String?,
      );
    }
  } catch (_) {
    return null;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Repository interfaces
// ---------------------------------------------------------------------------

abstract interface class ChatRepository {
  /// API-CHAT-01. [page] bắt đầu từ 1.
  Future<PageResult<ConversationSummary>> listConversations(
    int page, {
    int pageSize = 20,
  });

  /// API-CHAT-02: tìm hoặc tạo hội thoại cho Product.
  Future<ConversationRef> openConversation(String productId);

  /// API-CHAT-03: [before] là id tin (cursor), [limit] mặc định 30, tối đa 100.
  /// Tin trong một trang được trả theo thứ tự cũ -> mới.
  Future<PageResult<Message>> fetchMessages(
    String conversationId, {
    String? before,
    int limit = 30,
  });

  /// API-CHAT-04.
  Future<ReadReceipt> markRead(String conversationId);
}

/// Kết nối realtime. [events] phải sống qua nhiều lần [connect] (một stream
/// duy nhất cho cả vòng đời đối tượng) để controller chỉ cần subscribe một lần.
abstract interface class ChatSocket {
  Stream<ChatSocketEvent> get events;

  /// Mở kết nối. Ném (thường là `ApiException.network()`) nếu thất bại.
  Future<void> connect();

  /// Gửi `message.send`. Ném nếu không gửi được (chưa kết nối...).
  Future<void> send(
    String conversationId,
    String clientMessageId,
    String text,
  );

  /// Đóng chủ động; không phát [Disconnected].
  Future<void> close();
}

abstract interface class ReportRepository {
  /// API-REPORT-01. Trả về report vừa tạo (PENDING).
  Future<MyReport> createReport(
    String productId,
    ReportReason reason,
    String? description,
  );

  /// API-REPORT-02.
  Future<PageResult<MyReport>> myReports(int page, {int pageSize = 20});

  /// API-REPORT-03.
  Future<MyReport> myReport(String id);
}

abstract interface class AdminRepository {
  /// API-ADMIN-01. [status] null = tất cả.
  Future<PageResult<AdminReportItem>> listReports(
    ReportStatus? status,
    int page, {
    int pageSize = 20,
  });

  /// API-ADMIN-02.
  Future<AdminReportDetail> reportDetail(String id);

  /// API-ADMIN-03.
  Future<ResolveResult> resolve(String id, AdminAction action, String note);

  /// API-ADMIN-04.
  Future<BanResult> banUser(String userId, String reason);
}
