import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:tv4_prep/tv4_prep.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'chat_environment.dart';
import 'chat_widgets.dart';

enum _RoomMenu { viewProfile }

/// Phòng chat một-một về một sản phẩm (FR-CHAT-05..11, FR-CHAT-14, FR-CHAT-15).
///
/// Menu ⋮ chỉ có "Xem hồ sơ": báo cáo người dùng bị loại khỏi MVP (FR-CHAT-15).
class ChatRoomPage extends StatefulWidget {
  const ChatRoomPage({
    super.key,
    required this.environment,
    required this.conversation,
    this.isSeller,
    this.productPriceVnd,
  });

  final ChatEnvironment environment;
  final ConversationSummary conversation;

  /// Người dùng hiện tại là người bán? null = hỏi `environment.isSellerOf`
  /// (mặc định người mua). Quyết định bộ tin nhắn nhanh.
  final bool? isSeller;

  /// Giá để hiện trên thẻ sản phẩm (dữ liệu hội thoại không có giá).
  final int? productPriceVnd;

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  late final ChatController _controller;
  final TextEditingController _input = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ScrollController _scroll = ScrollController();
  StreamSubscription<ChatState>? _sub;
  String? _tailKey;

  ConversationSummary get _conversation => widget.conversation;
  String get _userId => widget.environment.userId;

  @override
  void initState() {
    super.initState();
    _controller = widget.environment.createController(_conversation);
    _tailKey = _tailKeyOf(_controller.state);
    _sub = _controller.states.listen(_onState);
    _scroll.addListener(_onScroll);
    // start() tự kết nối, tải lịch sử và đánh dấu đã đọc; không ném lỗi.
    unawaited(_controller.start());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scroll.dispose();
    _input.dispose();
    _focus.dispose();
    // Đóng socket + stream; giữ outbox để tin chưa gửi còn khi mở lại phòng.
    unawaited(_controller.dispose());
    super.dispose();
  }

  /// Khoá của tin cuối: ổn định qua pending -> sent (cùng clientMessageId).
  String? _tailKeyOf(ChatState s) =>
      s.messages.isEmpty ? null : (s.messages.last.clientMessageId ?? s.messages.last.id);

  void _onState(ChatState s) {
    final key = _tailKeyOf(s);
    if (key == _tailKey) return;
    _tailKey = key;
    // Danh sách đảo chiều nên tin mới tự nằm ở đáy khi đang ở đáy; chỉ cần kéo
    // xuống khi chính mình vừa gửi trong lúc đang đọc lịch sử phía trên.
    if (s.messages.last.senderId == _userId) _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    // Đảo chiều: đỉnh danh sách = maxScrollExtent. Sắp chạm đỉnh -> tải trang cũ.
    if (_scroll.position.extentAfter < 200) {
      unawaited(_controller.loadHistory());
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _send() async {
    final text = _input.text;
    final invalid = validateMessageText(text);
    if (invalid != null) {
      _snack(invalid);
      return;
    }
    // Xoá ô nhập ngay để người dùng gõ tiếp; nếu bị từ chối thì trả lại.
    _input.clear();
    final error = await _controller.send(text);
    if (!mounted) return;
    if (error != null) {
      if (_input.text.isEmpty) _input.text = text;
      _snack(error);
    }
  }

  void _fillQuickReply(String text) {
    // Chỉ điền vào ô nhập; người dùng tự bấm gửi (FR-CHAT-10).
    _input.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _focus.requestFocus();
  }

  void _viewProfile() {
    final hook = widget.environment.onViewProfile;
    if (hook != null) {
      hook(context, _conversation);
    } else {
      _snack('Hồ sơ của ${_conversation.other.displayName} (chưa nối màn hình).');
    }
  }

  void _openProduct() {
    final hook = widget.environment.onOpenProduct;
    if (hook != null) {
      hook(context, _conversation);
    } else {
      _snack('Chi tiết tin đăng (chưa nối màn hình).');
    }
  }

  String get _safetyTip {
    final i = _conversation.id.hashCode.abs() % kSafetyTips.length;
    return 'Mẹo an toàn: ${kSafetyTips[i]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _conversation.other.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: false,
        actions: [
          PopupMenuButton<_RoomMenu>(
            tooltip: 'Tuỳ chọn',
            onSelected: (_) => _viewProfile(),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _RoomMenu.viewProfile,
                child: Text('Xem hồ sơ'),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<ChatState>(
        initialData: _controller.state,
        stream: _controller.states,
        builder: (context, snapshot) => _buildRoom(snapshot.data!),
      ),
    );
  }

  Widget _buildRoom(ChatState state) {
    final isSeller = widget.isSeller ??
        widget.environment.isSellerOf?.call(_conversation) ??
        false;
    final readOnly = state.readOnly;

    return Column(
      children: [
        _buildConnectionBanner(state),
        ChatProductCard(
          title: _conversation.productTitle,
          priceVnd: widget.productPriceVnd,
          onTap: _openProduct,
        ),
        if (readOnly)
          const InfoBanner(
            text: kMsgChatReadOnly,
            background: AppColors.bubbleOther,
            foreground: AppColors.muted,
          )
        else
          InfoBanner(text: _safetyTip),
        if (!readOnly && state.error != null)
          InfoBanner(
            text: state.error!,
            background: AppColors.dangerSoft,
            foreground: AppColors.danger,
          ),
        Expanded(child: _buildMessages(state)),
        if (!readOnly)
          Container(
            color: AppColors.surface,
            child: QuickReplyBar(
              replies: isSeller ? kSellerQuickReplies : kBuyerQuickReplies,
              onSelected: _fillQuickReply,
            ),
          ),
        SafeArea(
          top: false,
          child: MessageComposer(
            controller: _input,
            focusNode: _focus,
            enabled: !readOnly,
            onSend: _send,
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionBanner(ChatState state) {
    if (state.readOnly) return const SizedBox.shrink();
    switch (state.connection) {
      case ChatConnectionStatus.reconnecting:
        return const InfoBanner(
          text: 'Không có kết nối mạng. Tin nhắn sẽ được gửi lại khi có mạng.',
        );
      case ChatConnectionStatus.disconnected:
        return InkWell(
          onTap: _controller.reconnect,
          child: const InfoBanner(
            text: 'Mất kết nối với máy chủ. Chạm để kết nối lại.',
          ),
        );
      case ChatConnectionStatus.idle:
      case ChatConnectionStatus.connecting:
      case ChatConnectionStatus.connected:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMessages(ChatState state) {
    if (state.messages.isEmpty) {
      final starting = state.loadingHistory ||
          state.connection == ChatConnectionStatus.idle ||
          state.connection == ChatConnectionStatus.connecting;
      if (starting) return const Center(child: CircularProgressIndicator());
      if (state.error != null) {
        return ErrorState(
          message: state.error!,
          onRetry: () => unawaited(_controller.loadHistory()),
        );
      }
      return const Center(
        child: Text(
          'Hãy gửi lời chào đầu tiên.',
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }

    final items = state.items;
    final now = widget.environment.now();
    final extra = state.loadingHistory ? 1 : 0;

    // Danh sách đảo chiều (đáy = offset 0) để tin mới nằm sát ô nhập và tải
    // lịch sử cũ không làm nhảy vị trí. Align + shrinkWrap để cuộc trò chuyện
    // ngắn nằm sát đầu màn hình thay vì sát đáy (khớp thiết kế).
    return Align(
      alignment: Alignment.topCenter,
      child: ListView.builder(
        key: const ValueKey('chat-messages'),
        controller: _scroll,
        reverse: true,
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: items.length + extra,
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final item = items[items.length - 1 - index];
          switch (item) {
            case DateDivider d:
              return DayDivider(
                key: ValueKey('day-${d.day.millisecondsSinceEpoch}'),
                label: formatDividerLabel(d.day, now: now),
              );
            case MessageItem m:
              final msg = m.message;
              return MessageBubble(
                key: ValueKey(msg.clientMessageId ?? msg.id),
                message: msg,
                mine: msg.senderId == _userId,
                onRetry: () => unawaited(_controller.retryFailed()),
              );
          }
        },
      ),
    );
  }
}
