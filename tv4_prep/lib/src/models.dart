/// Model theo docs/API.md (mục 4.6, 4.9, 4.10, 6.6, 6.8, 6.9).
library;

import 'enums.dart';

DateTime? _dt(Object? v) => v == null ? null : DateTime.parse(v as String);

class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.type,
    required this.text,
    required this.createdAt,
    this.clientMessageId,
    this.readAt,
    this.sendStatus = SendStatus.sent,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final MessageType type;
  final String text;
  final DateTime createdAt;
  final String? clientMessageId;
  final DateTime? readAt;
  final SendStatus sendStatus;

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: j['id'] as String,
        conversationId: j['conversation_id'] as String,
        senderId: j['sender_id'] as String,
        type: MessageType.fromCode(j['type'] as String?),
        text: (j['text'] as String?) ?? '',
        createdAt: DateTime.parse(j['created_at'] as String),
        clientMessageId: j['client_message_id'] as String?,
        readAt: _dt(j['read_at']),
      );

  Message copyWith({String? id, SendStatus? sendStatus, DateTime? createdAt}) =>
      Message(
        id: id ?? this.id,
        conversationId: conversationId,
        senderId: senderId,
        type: type,
        text: text,
        createdAt: createdAt ?? this.createdAt,
        clientMessageId: clientMessageId,
        readAt: readAt,
        sendStatus: sendStatus ?? this.sendStatus,
      );
}

class Participant {
  const Participant({required this.id, required this.displayName});
  final String id;
  final String displayName;

  factory Participant.fromJson(Map<String, dynamic> j) => Participant(
        id: j['id'] as String,
        displayName: j['display_name'] as String,
      );
}

class LastMessage {
  const LastMessage({required this.text, required this.createdAt});
  final String text;
  final DateTime createdAt;

  factory LastMessage.fromJson(Map<String, dynamic> j) => LastMessage(
        text: (j['text'] as String?) ?? '',
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

/// Một dòng trong danh sách hội thoại (GET /conversations).
class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.productId,
    required this.productTitle,
    required this.other,
    required this.unreadCount,
    this.lastMessage,
    this.status = ConversationStatus.open,
  });

  final String id;
  final String productId;
  final String productTitle;
  final Participant other;
  final LastMessage? lastMessage;
  final int unreadCount;
  final ConversationStatus status;

  bool get isReadOnly => status == ConversationStatus.readOnly;

  factory ConversationSummary.fromJson(Map<String, dynamic> j) {
    final lm = j['last_message'];
    return ConversationSummary(
      id: j['id'] as String,
      productId: j['product_id'] as String,
      productTitle: (j['product_title'] as String?) ?? '',
      other: Participant.fromJson(j['other_participant'] as Map<String, dynamic>),
      lastMessage:
          lm == null ? null : LastMessage.fromJson(lm as Map<String, dynamic>),
      unreadCount: (j['unread_count'] as int?) ?? 0,
      status: ConversationStatus.fromCode(j['status'] as String?),
    );
  }
}

/// Report của chính người dùng (GET /me/reports).
class MyReport {
  const MyReport({
    required this.id,
    required this.productId,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.productTitleSnapshot,
    this.description,
    this.resolutionNote,
    this.resolvedAt,
  });

  final String id;
  final String productId;
  final String? productTitleSnapshot;
  final ReportReason? reason;
  final String? description;
  final ReportStatus status;
  final DateTime createdAt;
  final String? resolutionNote;
  final DateTime? resolvedAt;

  factory MyReport.fromJson(Map<String, dynamic> j) => MyReport(
        id: j['id'] as String,
        productId: j['product_id'] as String,
        productTitleSnapshot: j['product_title_snapshot'] as String?,
        reason: ReportReason.fromCode(j['reason'] as String?),
        description: j['description'] as String?,
        status: ReportStatus.fromCode(j['status'] as String?),
        createdAt: DateTime.parse(j['created_at'] as String),
        resolutionNote: j['resolution_note'] as String?,
        resolvedAt: _dt(j['resolved_at']),
      );
}

/// Dòng trong hàng đợi Admin (GET /admin/reports).
class AdminReportItem {
  const AdminReportItem({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String targetType;
  final String targetId;
  final ReportReason? reason;
  final ReportStatus status;
  final DateTime createdAt;

  factory AdminReportItem.fromJson(Map<String, dynamic> j) => AdminReportItem(
        id: j['id'] as String,
        targetType: j['target_type'] as String,
        targetId: j['target_id'] as String,
        reason: ReportReason.fromCode(j['reason'] as String?),
        status: ReportStatus.fromCode(j['status'] as String?),
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

/// Chi tiết report cho Admin (GET /admin/reports/{id}).
class AdminReportDetail {
  const AdminReportDetail({
    required this.id,
    required this.reporterName,
    required this.targetId,
    required this.targetStatus,
    required this.snapshotTitle,
    required this.snapshotPriceVnd,
    required this.reason,
    required this.status,
    this.snapshotCoverImageUrl,
    this.description,
  });

  final String id;
  final String reporterName;
  final String targetId;
  final String targetStatus;
  final String snapshotTitle;
  final int snapshotPriceVnd;
  final String? snapshotCoverImageUrl;
  final ReportReason? reason;
  final String? description;
  final ReportStatus status;

  /// Chỉ cho xử lý khi còn PENDING (E-15/E-16).
  bool get canResolve => status == ReportStatus.pending;

  factory AdminReportDetail.fromJson(Map<String, dynamic> j) {
    final reporter = j['reporter'] as Map<String, dynamic>;
    final target = j['target'] as Map<String, dynamic>;
    final snap = j['snapshot'] as Map<String, dynamic>;
    return AdminReportDetail(
      id: j['id'] as String,
      reporterName: reporter['display_name'] as String,
      targetId: target['id'] as String,
      targetStatus: target['status'] as String,
      snapshotTitle: snap['title'] as String,
      snapshotPriceVnd: snap['price_vnd'] as int,
      snapshotCoverImageUrl: snap['cover_image_url'] as String?,
      reason: ReportReason.fromCode(j['reason'] as String?),
      description: j['description'] as String?,
      status: ReportStatus.fromCode(j['status'] as String?),
    );
  }
}
