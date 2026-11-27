import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tv4_app/core/theme.dart';
import 'package:tv4_app/features/chat/chat_routes.dart';
import 'package:tv4_prep/tv4_prep.dart';

const String kMe = 'usr_01JBUYER1';
const String kOther = 'usr_01JABC123';
const String kConvId = 'cnv_01JCONV1';

/// Dữ liệu giả + môi trường Chat dùng cho test. Không có timer thật: hàm chờ
/// của vòng nối lại là bản giả (không bao giờ kết thúc nếu [manualDelay]).
class ChatHarness {
  ChatHarness({
    bool seed = true,
    this.manualDelay = false,
    bool readOnly = false,
  }) : repo = FakeChatRepository(seed: seed) {
    if (seed && readOnly) {
      final c = repo.conversations.first;
      repo.conversations[0] = ConversationSummary(
        id: c.id,
        productId: c.productId,
        productTitle: c.productTitle,
        other: c.other,
        lastMessage: c.lastMessage,
        unreadCount: c.unreadCount,
        status: ConversationStatus.readOnly,
      );
    }
    var n = 0;
    env = ChatEnvironment(
      userId: kMe,
      repository: repo,
      socketFactory: (_) {
        final s = FakeChatSocket(repository: repo, userId: kMe)
          ..offline = socketsOffline;
        sockets.add(s);
        return s;
      },
      delay: (_) => manualDelay ? Completer<void>().future : Future<void>.value(),
      newClientMessageId: () => 'cid-${++n}',
      now: () => DateTime(2026, 11, 27, 12),
    );
  }

  final FakeChatRepository repo;
  final bool manualDelay;
  late final ChatEnvironment env;
  final List<FakeChatSocket> sockets = [];

  /// true: socket tạo sau đó không kết nối được.
  bool socketsOffline = false;

  Widget app({String initialRoute = kChatListRoute}) => MaterialApp(
        theme: buildAppTheme(),
        initialRoute: initialRoute,
        routes: chatRoutes(environment: env),
      );
}

/// Nhường event loop cho các Future của fake (chỉ microtask) và chạy xong
/// animation chuyển trang, không phụ thuộc pumpAndSettle (có spinner).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Màn hình cỡ điện thoại.
void usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Message incoming(String id, String text, DateTime at) => Message(
      id: id,
      conversationId: kConvId,
      senderId: kOther,
      type: MessageType.text,
      text: text,
      createdAt: at,
    );
