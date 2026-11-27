/// Các widget con của khu vực Chat (không gắn với controller nào).
library;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tv4_prep/tv4_prep.dart';

import '../../core/theme.dart';
import 'chat_format.dart';

/// Chấm tròn số tin chưa đọc.
class UnreadBadge extends StatelessWidget {
  const UnreadBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$count tin chưa đọc',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.onPrimary,
          ),
        ),
      ),
    );
  }
}

/// Thẻ sản phẩm dưới AppBar của phòng chat (FR-CHAT-05).
/// `ConversationSummary` chỉ có tên sản phẩm nên ảnh là ô giữ chỗ; [priceVnd]
/// chỉ hiện khi nơi gọi có giá.
class ChatProductCard extends StatelessWidget {
  const ChatProductCard({
    super.key,
    required this.title,
    this.priceVnd,
    this.onTap,
  });

  final String title;
  final int? priceVnd;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.image_outlined, color: AppColors.muted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? 'Tin đăng' : title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    if (priceVnd != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          formatVnd(priceVnd!),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nhãn phân cách ngày giữa các tin.
class DayDivider extends StatelessWidget {
  const DayDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ),
    );
  }
}

/// Bong bóng tin nhắn kèm dòng trạng thái gửi (FR-CHAT-07).
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.mine,
    this.onRetry,
  });

  final Message message;
  final bool mine;

  /// Chạm vào tin gửi lỗi.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (message.type == MessageType.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 32),
        child: Center(
          child: Text(
            message.text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ),
      );
    }

    final failed = mine && message.sendStatus == SendStatus.failed;
    final bubble = Container(
      constraints:
          BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: mine ? AppColors.primary : AppColors.bubbleOther,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message.text,
        style: TextStyle(
          fontSize: 14,
          color: mine ? AppColors.onPrimary : AppColors.text,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(onTap: failed ? onRetry : null, child: bubble),
          if (mine) _StatusLine(message: message, onRetry: onRetry),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.message, this.onRetry});

  final Message message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    switch (message.sendStatus) {
      case SendStatus.pending:
        return const _StatusText('Đang gửi…');
      case SendStatus.failed:
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onRetry,
          child: const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
              'Gửi lỗi · Chạm để thử lại',
              style: TextStyle(fontSize: 11, color: AppColors.danger),
            ),
          ),
        );
      case SendStatus.sent:
        final time = formatClock(message.createdAt);
        return _StatusText(
          message.readAt != null ? 'Đã đọc $time' : 'Đã gửi $time',
        );
    }
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, color: AppColors.muted),
      ),
    );
  }
}

/// Hàng tin nhắn nhanh cuộn ngang. Chạm chỉ gọi [onSelected] (điền vào ô
/// nhập), không gửi (FR-CHAT-10).
class QuickReplyBar extends StatelessWidget {
  const QuickReplyBar({
    super.key,
    required this.replies,
    required this.onSelected,
  });

  final List<String> replies;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: replies.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final text = replies[i];
          return Material(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onSelected(text),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Center(
                  child: Text(
                    text,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.primary),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Ô nhập tin + nút gửi. [enabled] = false cho phòng chỉ đọc.
class MessageComposer extends StatelessWidget {
  const MessageComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('chat-input'),
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [
                LengthLimitingTextInputFormatter(kMessageMaxLength),
              ],
              decoration: InputDecoration(
                hintText: enabled ? 'Nhập tin nhắn…' : 'Không thể nhắn tin',
                isDense: true,
                filled: true,
                fillColor: enabled ? AppColors.surface : AppColors.bg,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final canSend =
                  enabled && validateMessageText(value.text) == null;
              return IconButton.filled(
                key: const ValueKey('chat-send'),
                tooltip: 'Gửi',
                onPressed: canSend ? onSend : null,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  disabledBackgroundColor: AppColors.border,
                  disabledForegroundColor: AppColors.muted,
                ),
                icon: const Icon(Icons.send, size: 20),
              );
            },
          ),
        ],
      ),
    );
  }
}
