/// Logic thuần cho phòng chat: gộp ngày, outbox, backoff, ánh xạ lỗi.
library;

import 'constants.dart';
import 'enums.dart';
import 'models.dart';

// ---------- Phân cách ngày (FR-CHAT-08) ----------

sealed class ChatItem {}

class DateDivider extends ChatItem {
  DateDivider(this.day);
  final DateTime day; // 00:00 theo giờ local
}

class MessageItem extends ChatItem {
  MessageItem(this.message);
  final Message message;
}

DateTime _dayOf(DateTime t) {
  final l = t.toLocal();
  return DateTime(l.year, l.month, l.day);
}

/// Sắp xếp theo thời gian tăng dần và chèn [DateDivider] khi sang ngày mới.
List<ChatItem> groupByDay(List<Message> messages) {
  final sorted = [...messages]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final out = <ChatItem>[];
  DateTime? current;
  for (final m in sorted) {
    final d = _dayOf(m.createdAt);
    if (current != d) {
      out.add(DateDivider(d));
      current = d;
    }
    out.add(MessageItem(m));
  }
  return out;
}

/// "Hôm nay" / "Hôm qua" / dd/MM/yyyy.
String formatDividerLabel(DateTime day, {required DateTime now}) {
  // So sánh bằng UTC để không bị lệch 1 ngày khi múi giờ có DST.
  final today = DateTime.utc(now.year, now.month, now.day);
  final diff = today.difference(DateTime.utc(day.year, day.month, day.day)).inDays;
  if (diff == 0) return 'Hôm nay';
  if (diff == 1) return 'Hôm qua';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(day.day)}/${two(day.month)}/${day.year}';
}

// ---------- Hợp nhất tin từ nhiều nguồn (AC-CHAT-06, AC-ERR-04) ----------

/// Gộp danh sách hiện có với tin mới (REST history / WebSocket).
/// Khử trùng theo `id`, và theo `clientMessageId` để tin local đang pending
/// được thay bằng bản server khi có ACK.
List<Message> mergeMessages(List<Message> existing, List<Message> incoming) {
  final byId = <String, Message>{};
  final byClient = <String, String>{}; // clientMessageId -> key trong byId

  void put(Message m) {
    final cid = m.clientMessageId;
    if (cid != null && byClient.containsKey(cid)) {
      final oldKey = byClient[cid]!;
      final old = byId[oldKey]!;
      // Bản đã gửi (server) luôn thắng bản pending/failed.
      if (old.sendStatus != SendStatus.sent && m.sendStatus == SendStatus.sent) {
        byId.remove(oldKey);
      } else if (m.sendStatus != SendStatus.sent) {
        return;
      } else {
        byId.remove(oldKey);
      }
    }
    byId[m.id] = m;
    if (cid != null) byClient[cid] = m.id;
  }

  for (final m in existing) {
    put(m);
  }
  for (final m in incoming) {
    put(m);
  }
  return byId.values.toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
}

// ---------- Outbox theo từng user (FR-CHAT-07, AC-CHAT-08, E-20) ----------

class OutboxEntry {
  OutboxEntry({
    required this.clientMessageId,
    required this.conversationId,
    required this.text,
    required this.createdAt,
    this.status = SendStatus.pending,
    this.attempts = 0,
  });

  final String clientMessageId; // giữ nguyên qua các lần retry
  final String conversationId;
  final String text;
  final DateTime createdAt;
  SendStatus status;
  int attempts;
}

class Outbox {
  Outbox({this.maxAttempts = 5});

  final int maxAttempts;
  // userId -> các tin chưa gửi. Tách theo user để logout/đổi tài khoản
  // không gửi nhầm.
  final Map<String, List<OutboxEntry>> _byUser = {};

  List<OutboxEntry> entriesFor(String userId) =>
      List.unmodifiable(_byUser[userId] ?? const []);

  void add(String userId, OutboxEntry e) =>
      (_byUser[userId] ??= []).add(e);

  /// Tin cần gửi lại: chỉ của [userId], còn pending và chưa vượt số lần thử.
  List<OutboxEntry> retryable(String userId) => entriesFor(userId)
      .where((e) => e.status == SendStatus.pending && e.attempts < maxAttempts)
      .toList();

  /// Ghi nhận một lần thử; quá [maxAttempts] thì chuyển failed
  /// (không retry vô hạn, AC-ERR-05).
  void markAttempt(String userId, String clientMessageId) {
    for (final e in _byUser[userId] ?? const <OutboxEntry>[]) {
      if (e.clientMessageId == clientMessageId) {
        e.attempts++;
        if (e.attempts >= maxAttempts) e.status = SendStatus.failed;
      }
    }
  }

  /// Server đã ACK -> bỏ khỏi outbox.
  void markSent(String userId, String clientMessageId) =>
      _byUser[userId]?.removeWhere((e) => e.clientMessageId == clientMessageId);

  /// Server báo hội thoại đóng / user bị ban / product không hợp lệ.
  void failConversation(String userId, String conversationId) {
    for (final e in _byUser[userId] ?? const <OutboxEntry>[]) {
      if (e.conversationId == conversationId &&
          e.status == SendStatus.pending) {
        e.status = SendStatus.failed;
      }
    }
  }

  void clearUser(String userId) => _byUser.remove(userId);
}

// ---------- Reconnect backoff (E-19) ----------

/// 1s, 2s, 4s, 8s, 16s, rồi giữ ở [max]. [attempt] bắt đầu từ 0.
Duration reconnectDelay(
  int attempt, {
  Duration base = const Duration(seconds: 1),
  Duration max = const Duration(seconds: 30),
}) {
  if (attempt < 0) attempt = 0;
  final shift = attempt > 20 ? 20 : attempt; // tránh tràn số
  final ms = base.inMilliseconds * (1 << shift);
  return ms >= max.inMilliseconds ? max : Duration(milliseconds: ms);
}

// ---------- Ánh xạ mã lỗi -> thông báo tiếng Việt (AC-ERR-01) ----------

/// [code] là mã lỗi trong response envelope (vd REPORT_ALREADY_PENDING).
/// Không bao giờ trả về traceback hay nội dung kỹ thuật.
String messageForError({String? code, int? httpStatus}) {
  switch (code) {
    case 'REPORT_ALREADY_PENDING':
      return kMsgAlreadyReported;
    case 'REPORT_RATE_LIMITED':
      return kMsgReportRateLimited;
    case 'REPORT_ALREADY_RESOLVED':
      return kMsgReportAlreadyResolved;
    case 'PRODUCT_NOT_AVAILABLE':
      return kMsgProductUnavailable;
    case 'PRODUCT_NOT_FOUND':
      return kMsgProductGone;
    case 'TOKEN_EXPIRED':
      return kMsgSessionExpired;
    case 'ADMIN_REQUIRED':
      return kMsgForbidden;
  }
  switch (httpStatus) {
    case 401:
      return kMsgSessionExpired;
    case 403:
      return kMsgForbidden;
    case 404:
      return kMsgProductGone;
  }
  return kMsgGeneric;
}
