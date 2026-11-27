import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tv4_app/core/widgets.dart';
import 'package:tv4_app/features/chat/chat_widgets.dart';
import 'package:tv4_prep/tv4_prep.dart';

import 'chat_test_support.dart';

final _input = find.byKey(const ValueKey('chat-input'));
final _send = find.byKey(const ValueKey('chat-send'));

Future<void> _openRoom(WidgetTester tester, ChatHarness h) async {
  await tester.pumpWidget(h.app());
  await settle(tester);
  await tester.tap(find.text('Nguyen Van A'));
  await settle(tester);
}

String _inputText(WidgetTester tester) =>
    tester.widget<TextField>(_input).controller!.text;

void main() {
  testWidgets('mở phòng chat: AppBar, thẻ sản phẩm, mẹo an toàn, lịch sử, đã đọc',
      (tester) async {
    usePhoneSurface(tester);
    final h = ChatHarness();
    await _openRoom(tester, h);

    expect(find.descendant(of: find.byType(AppBar), matching: find.text('Nguyen Van A')),
        findsOneWidget); // tên đối phương trên AppBar
    expect(find.byType(ChatProductCard), findsOneWidget);
    expect(find.descendant(of: find.byType(ChatProductCard), matching: find.text('Giao trinh Giai tich 1')),
        findsOneWidget);
    expect(find.textContaining('Mẹo an toàn:'), findsOneWidget);
    expect(find.text('Mon nay con khong ban?'), findsOneWidget);
    expect(find.text('Hôm nay'), findsOneWidget); // phân cách ngày
    expect(find.textContaining('Đã gửi'), findsOneWidget);
    expect(find.text(kBuyerQuickReplies.first), findsOneWidget);
    expect(h.repo.markReadCalls, 1); // đánh dấu đã đọc khi mở phòng

    // Quay lại danh sách: badge chưa đọc đã biến mất.
    await tester.pageBack();
    await settle(tester);
    expect(find.text('2'), findsNothing);
  });

  testWidgets('menu ⋮ chỉ có "Xem hồ sơ", không có báo cáo người dùng',
      (tester) async {
    usePhoneSurface(tester);
    final h = ChatHarness();
    await _openRoom(tester, h);

    await tester.tap(find.byTooltip('Tuỳ chọn'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Xem hồ sơ'), findsOneWidget);
    expect(find.textContaining('Báo cáo'), findsNothing);
    expect(find.byWidgetPredicate((w) => w is PopupMenuItem), findsOneWidget);
  });

  testWidgets('gửi tin: bong bóng hiện ngay, ô nhập được xoá, tin được gửi qua socket',
      (tester) async {
    usePhoneSurface(tester);
    final h = ChatHarness();
    await _openRoom(tester, h);

    // Rỗng thì nút gửi bị khoá.
    expect(tester.widget<IconButton>(_send).onPressed, isNull);

    await tester.enterText(_input, 'Mình lấy hôm nay nhé');
    await tester.pump();
    expect(tester.widget<IconButton>(_send).onPressed, isNotNull);
    await tester.tap(_send);
    await tester.pump(); // bong bóng pending xuất hiện trước khi có ACK
    expect(find.text('Mình lấy hôm nay nhé'), findsOneWidget);
    await settle(tester);

    expect(_inputText(tester), isEmpty);
    expect(find.text('Mình lấy hôm nay nhé'), findsOneWidget);
    expect(find.text('Đang gửi…'), findsNothing);
    expect(find.textContaining('Đã gửi'), findsNWidgets(2));
    expect(h.sockets.single.sent.single.text, 'Mình lấy hôm nay nhé');
    expect(h.sockets.single.sent.single.conversationId, kConvId);
  });

  testWidgets('tin nhắn đến từ đối phương hiện thành bong bóng', (tester) async {
    usePhoneSurface(tester);
    final h = ChatHarness();
    await _openRoom(tester, h);

    h.sockets.single.simulateIncoming(
      incoming('msg_in_1', 'Hẹn gặp ở căn tin nhé', DateTime.utc(2026, 11, 27, 13)),
    );
    await settle(tester);

    expect(find.text('Hẹn gặp ở căn tin nhé'), findsOneWidget);
  });

  testWidgets('quick reply chỉ điền vào ô nhập, không tự gửi', (tester) async {
    usePhoneSurface(tester);
    final h = ChatHarness();
    await _openRoom(tester, h);
    final bubblesBefore = tester.widgetList(find.byType(MessageBubble)).length;

    await tester.tap(find.text(kBuyerQuickReplies.first));
    await settle(tester);

    expect(_inputText(tester), kBuyerQuickReplies.first);
    expect(h.sockets.single.sent, isEmpty);
    expect(tester.widgetList(find.byType(MessageBubble)).length, bubblesBefore);
    // Người dùng tự bấm gửi.
    await tester.tap(_send);
    await settle(tester);
    expect(h.sockets.single.sent.single.text, kBuyerQuickReplies.first);
  });

  testWidgets('chế độ chỉ đọc: khoá ô nhập, hiện banner, ẩn quick reply',
      (tester) async {
    usePhoneSurface(tester);
    final h = ChatHarness(readOnly: true);
    await _openRoom(tester, h);

    expect(find.text('Cuộc trò chuyện này chỉ còn có thể đọc.'), findsOneWidget);
    expect(tester.widget<TextField>(_input).enabled, isFalse);
    expect(tester.widget<IconButton>(_send).onPressed, isNull);
    expect(find.byType(QuickReplyBar), findsNothing);
    expect(find.textContaining('Mẹo an toàn:'), findsNothing);
    // Vẫn đọc được lịch sử.
    expect(find.text('Mon nay con khong ban?'), findsOneWidget);
  });

  testWidgets('mất mạng: banner, tin gửi ở trạng thái "Đang gửi…"', (tester) async {
    usePhoneSurface(tester);
    final h = ChatHarness(manualDelay: true)..socketsOffline = true;
    await _openRoom(tester, h);

    expect(
      find.text('Không có kết nối mạng. Tin nhắn sẽ được gửi lại khi có mạng.'),
      findsOneWidget,
    );
    // Lịch sử vẫn tải được qua REST.
    expect(find.text('Mon nay con khong ban?'), findsOneWidget);

    await tester.enterText(_input, 'Ok bạn, hẹn gặp ở căn tin');
    await tester.pump();
    await tester.tap(_send);
    await settle(tester);

    expect(find.text('Ok bạn, hẹn gặp ở căn tin'), findsOneWidget);
    expect(find.text('Đang gửi…'), findsOneWidget);
    expect(h.sockets.single.sent, isEmpty);
  });

  testWidgets('tin gửi lỗi: chạm để thử lại thì gửi lại cùng clientMessageId',
      (tester) async {
    usePhoneSurface(tester);
    final h = ChatHarness();
    h.env.outbox.add(
      kMe,
      OutboxEntry(
        clientMessageId: 'cid-failed',
        conversationId: kConvId,
        text: 'Tin gửi lỗi',
        createdAt: DateTime.utc(2026, 11, 27, 5),
        status: SendStatus.failed,
      ),
    );
    await _openRoom(tester, h);

    expect(find.text('Gửi lỗi · Chạm để thử lại'), findsOneWidget);
    expect(h.sockets.single.sent, isEmpty);

    await tester.tap(find.text('Gửi lỗi · Chạm để thử lại'));
    await settle(tester);

    expect(find.text('Gửi lỗi · Chạm để thử lại'), findsNothing);
    expect(h.sockets.single.sent.single.clientMessageId, 'cid-failed');
    expect(find.text('Tin gửi lỗi'), findsOneWidget);
  });

  testWidgets('lỗi tải lịch sử lần đầu: ErrorState có Thử lại', (tester) async {
    usePhoneSurface(tester);
    final h = ChatHarness();
    await tester.pumpWidget(h.app());
    await settle(tester);
    h.repo.faults.failOnce(ApiException.network());
    await tester.tap(find.text('Nguyen Van A'));
    await settle(tester);

    expect(find.byType(ErrorState), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await settle(tester);
    expect(find.byType(ErrorState), findsNothing);
    expect(find.text('Mon nay con khong ban?'), findsOneWidget);
  });

  testWidgets('cuộn lên đầu thì tải thêm lịch sử', (tester) async {
    usePhoneSurface(tester);
    final h = ChatHarness(seed: false);
    h.repo.conversations.add(const ConversationSummary(
      id: 'cnv_big',
      productId: 'prd_big',
      productTitle: 'Xe dap',
      other: Participant(id: 'usr_big', displayName: 'Hoang Long'),
      unreadCount: 0,
    ));
    for (var i = 0; i < 75; i++) {
      h.repo.addMessage(Message(
        id: 'msg_${i.toString().padLeft(3, '0')}',
        conversationId: 'cnv_big',
        senderId: i.isEven ? kMe : 'usr_big',
        type: MessageType.text,
        text: 'Tin so $i',
        createdAt: DateTime.utc(2026, 11, 27, 1).add(Duration(minutes: i)),
      ));
    }
    await tester.pumpWidget(h.app());
    await settle(tester);
    await tester.tap(find.text('Hoang Long'));
    await settle(tester);

    expect(h.repo.fetchMessagesCalls, 1);
    expect(find.text('Tin so 74'), findsOneWidget); // tin mới nhất ở đáy
    expect(find.text('Tin so 0'), findsNothing);

    await tester.fling(
      find.byKey(const ValueKey('chat-messages')),
      const Offset(0, 1500),
      3000,
    );
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(h.repo.fetchMessagesCalls, greaterThanOrEqualTo(2));
  });
}
