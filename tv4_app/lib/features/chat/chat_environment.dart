/// Gom các phụ thuộc của khu vực Chat (người dùng hiện tại, repository, socket,
/// outbox...). Màn hình chỉ biết [ChatEnvironment]; khi nối API thật chỉ cần
/// dựng một [ChatEnvironment] khác (HTTP repository + WebSocket thật).
library;

import 'package:material_ui/material_ui.dart';
import 'package:tv4_prep/tv4_prep.dart';

/// Người dùng mẫu trong dữ liệu của `FakeChatRepository` (người mua).
const String kDemoUserId = 'usr_01JBUYER1';

typedef ChatSocketFactory = ChatSocket Function(ConversationSummary conversation);

class ChatEnvironment {
  ChatEnvironment({
    required this.userId,
    required this.repository,
    required this.socketFactory,
    Outbox? outbox,
    this.delay,
    this.newClientMessageId,
    this.now = DateTime.now,
    this.isSellerOf,
    this.onViewProfile,
    this.onOpenProduct,
  }) : outbox = outbox ?? Outbox();

  /// Bản chạy bằng dữ liệu giả (không cần backend), có thêm vài hội thoại mẫu
  /// để xem đủ các trạng thái (có chưa đọc, chỉ đọc, nhiều tin...).
  factory ChatEnvironment.demo({String userId = kDemoUserId}) {
    final repository = FakeChatRepository();
    _seedDemo(repository, userId);
    return ChatEnvironment(
      userId: userId,
      repository: repository,
      socketFactory: (_) => FakeChatSocket(
        repository: repository,
        userId: userId,
        clock: () => DateTime.now().toUtc(),
      ),
    );
  }

  final String userId;
  final ChatRepository repository;
  final ChatSocketFactory socketFactory;

  /// Dùng chung giữa các phòng để tin chưa gửi không mất khi thoát phòng.
  final Outbox outbox;

  /// Hàm chờ cho vòng nối lại (null = chờ thật). Test truyền bản giả.
  final Future<void> Function(Duration)? delay;
  final String Function()? newClientMessageId;

  /// Đồng hồ cho nhãn ngày / giờ (test truyền giờ cố định).
  final DateTime Function() now;

  /// Cho biết người dùng hiện tại là người bán trong hội thoại nào (để chọn bộ
  /// tin nhắn nhanh). Mặc định coi là người mua vì `ConversationSummary` không
  /// có trường vai trò.
  final bool Function(ConversationSummary conversation)? isSellerOf;

  /// Hook điều hướng sang màn hồ sơ / chi tiết tin đăng của module khác.
  /// Để null thì hiện SnackBar báo chưa nối màn hình.
  final void Function(BuildContext context, ConversationSummary conversation)?
      onViewProfile;
  final void Function(BuildContext context, ConversationSummary conversation)?
      onOpenProduct;

  ChatController createController(ConversationSummary conversation) {
    return ChatController(
      conversationId: conversation.id,
      userId: userId,
      repository: repository,
      socket: socketFactory(conversation),
      outbox: outbox,
      delay: delay,
      newClientMessageId: newClientMessageId,
      initialReadOnly: conversation.isReadOnly,
    );
  }
}

void _seedDemo(FakeChatRepository repo, String userId) {
  final now = DateTime.now().toUtc();

  repo.addMessage(Message(
    id: 'msg_demo_1b',
    conversationId: 'cnv_01JCONV1',
    senderId: 'usr_01JABC123',
    type: MessageType.text,
    text: 'Còn nhé bạn, bạn xem trực tiếp ở KTX khu B được không?',
    createdAt: DateTime.utc(2026, 11, 27, 4, 20),
  ));
  repo.addMessage(Message(
    id: 'msg_demo_1c',
    conversationId: 'cnv_01JCONV1',
    senderId: userId,
    type: MessageType.text,
    text: 'Được bạn, mình hẹn 5h nhé',
    createdAt: DateTime.utc(2026, 11, 27, 4, 25),
  ));
  repo.addMessage(Message(
    id: 'msg_demo_1d',
    conversationId: 'cnv_01JCONV1',
    senderId: 'usr_01JABC123',
    type: MessageType.text,
    text: 'Mình hẹn 5h nhé',
    createdAt: DateTime.utc(2026, 11, 27, 4, 30),
  ));

  // Hội thoại chỉ đọc (tin đăng đã bị gỡ).
  final lastB = now.subtract(const Duration(days: 1));
  repo.conversations.add(ConversationSummary(
    id: 'cnv_demo_2',
    productId: 'prd_demo_2',
    productTitle: 'Đèn bàn LED',
    other: const Participant(id: 'usr_demo_b', displayName: 'Trần Thị B'),
    lastMessage:
        LastMessage(text: 'Giá này mình để hợp lý rồi bạn ạ.', createdAt: lastB),
    unreadCount: 0,
    status: ConversationStatus.readOnly,
  ));
  repo.addMessage(Message(
    id: 'msg_demo_2a',
    conversationId: 'cnv_demo_2',
    senderId: userId,
    type: MessageType.text,
    text: 'Giá có thương lượng được không?',
    createdAt: lastB.subtract(const Duration(minutes: 5)),
  ));
  repo.addMessage(Message(
    id: 'msg_demo_2b',
    conversationId: 'cnv_demo_2',
    senderId: 'usr_demo_b',
    type: MessageType.text,
    text: 'Giá này mình để hợp lý rồi bạn ạ.',
    createdAt: lastB,
  ));

  // Hội thoại có nhiều tin để thử tải thêm lịch sử khi cuộn lên.
  final lastC = now.subtract(const Duration(days: 3));
  repo.conversations.add(ConversationSummary(
    id: 'cnv_demo_3',
    productId: 'prd_demo_3',
    productTitle: 'Xe đạp Giant cũ',
    other: const Participant(id: 'usr_demo_c', displayName: 'Lê Văn C'),
    lastMessage: LastMessage(text: 'Bạn tiện gặp lúc nào?', createdAt: lastC),
    unreadCount: 0,
  ));
  for (var i = 0; i < 70; i++) {
    final mine = i.isEven;
    repo.addMessage(Message(
      id: 'msg_demo_3_${i.toString().padLeft(3, '0')}',
      conversationId: 'cnv_demo_3',
      senderId: mine ? userId : 'usr_demo_c',
      type: MessageType.text,
      text: i == 69 ? 'Bạn tiện gặp lúc nào?' : 'Tin mẫu số ${i + 1}',
      createdAt: lastC.subtract(Duration(minutes: 70 - i)),
    ));
  }
}
