import 'package:material_ui/material_ui.dart';
import 'package:tv4_prep/tv4_prep.dart';

import 'chat_environment.dart';
import 'chat_room_page.dart';
import 'conversation_list_page.dart';

export 'chat_environment.dart' show ChatEnvironment, kDemoUserId;

/// Route của khu vực Chat.
const String kChatListRoute = '/chat';

/// Phòng chat; nhận [ConversationSummary] qua `arguments`.
const String kChatRoomRoute = '/chat/room';

/// [environment] mặc định là bản dữ liệu giả ([ChatEnvironment.demo]).
Map<String, WidgetBuilder> chatRoutes({ChatEnvironment? environment}) {
  final env = environment ?? ChatEnvironment.demo();
  return {
    kChatListRoute: (_) => ConversationListPage(environment: env),
    kChatRoomRoute: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is ConversationSummary) {
        return ChatRoomPage(environment: env, conversation: args);
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Tin nhắn')),
        body: const Center(child: Text('Không tìm thấy cuộc trò chuyện.')),
      );
    },
  };
}
