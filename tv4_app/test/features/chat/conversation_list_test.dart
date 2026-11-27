import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tv4_app/core/widgets.dart';
import 'package:tv4_prep/tv4_prep.dart';

import 'chat_test_support.dart';

void main() {
  testWidgets('hiển thị hội thoại mẫu: tên, sản phẩm, tin cuối, badge chưa đọc',
      (tester) async {
    usePhoneSurface(tester);
    final h = ChatHarness();
    await tester.pumpWidget(h.app());
    await settle(tester);

    expect(find.text('Tin nhắn'), findsOneWidget);
    expect(find.text('Nguyen Van A'), findsOneWidget);
    expect(find.text('Giao trinh Giai tich 1'), findsOneWidget);
    expect(find.text('Minh hen 5h nhe'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // badge chưa đọc
    expect(find.byType(InitialsAvatar), findsOneWidget);
    expect(find.text('NA'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget); // ô tìm kiếm
  });

  testWidgets('danh sách rỗng: EmptyState, không có ô tìm kiếm', (tester) async {
    usePhoneSurface(tester);
    final h = ChatHarness(seed: false);
    await tester.pumpWidget(h.app());
    await settle(tester);

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Chưa có cuộc trò chuyện nào'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('lỗi tải: ErrorState, bấm Thử lại thì tải được', (tester) async {
    usePhoneSurface(tester);
    final h = ChatHarness();
    h.repo.faults.offline = true;
    await tester.pumpWidget(h.app());
    await settle(tester);

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text(kMsgOffline), findsOneWidget);

    h.repo.faults.offline = false;
    await tester.tap(find.text('Thử lại'));
    await settle(tester);

    expect(find.byType(ErrorState), findsNothing);
    expect(find.text('Nguyen Van A'), findsOneWidget);
  });

  testWidgets('tìm kiếm lọc tại chỗ, không có kết quả thì báo', (tester) async {
    usePhoneSurface(tester);
    final h = ChatHarness();
    h.repo.conversations.add(const ConversationSummary(
      id: 'cnv_2',
      productId: 'prd_2',
      productTitle: 'Den ban LED',
      other: Participant(id: 'usr_b', displayName: 'Tran Thi B'),
      unreadCount: 0,
    ));
    await tester.pumpWidget(h.app());
    await settle(tester);
    expect(find.text('Tran Thi B'), findsOneWidget);
    expect(find.text('Nguyen Van A'), findsOneWidget);
    // Hội thoại chưa có tin nhắn.
    expect(find.text('Chưa có tin nhắn'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'led');
    await tester.pump();
    expect(find.text('Tran Thi B'), findsOneWidget);
    expect(find.text('Nguyen Van A'), findsNothing);

    await tester.enterText(find.byType(TextField), 'khong co');
    await tester.pump();
    expect(find.text('Không tìm thấy hội thoại phù hợp'), findsOneWidget);
    expect(h.repo.listCalls, 1); // lọc tại chỗ, không gọi lại API
  });

  testWidgets('kéo để làm mới gọi lại API', (tester) async {
    usePhoneSurface(tester);
    final h = ChatHarness();
    await tester.pumpWidget(h.app());
    await settle(tester);
    expect(h.repo.listCalls, 1);

    await tester.fling(find.text('Nguyen Van A'), const Offset(0, 400), 1000);
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(h.repo.listCalls, 2);
  });
}
