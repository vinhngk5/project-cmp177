import 'package:material_ui/material_ui.dart';

import 'core/theme.dart';
import 'core/widgets.dart';
import 'features/admin/admin_routes.dart';
import 'features/chat/chat_routes.dart';
import 'features/report/report_routes.dart';

void main() {
  runApp(const Tv4App());
}

/// Ứng dụng tạm để chạy riêng các màn của TV4 (Chat, Báo cáo, Admin) với dữ liệu giả.
/// Khi TV2 có khung Flutter chung, các thư mục `features/` được chuyển sang đó.
class Tv4App extends StatelessWidget {
  const Tv4App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CMP177 – TV4',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routes: {
        '/': (_) => const _LauncherPage(),
        ...chatRoutes(),
        ...reportRoutes(),
        ...adminRoutes(),
      },
    );
  }
}

class _LauncherPage extends StatelessWidget {
  const _LauncherPage();

  @override
  Widget build(BuildContext context) {
    final entries = <(String, String)>[
      ('Chat – danh sách hội thoại', kChatListRoute),
      ('Báo cáo tin đăng', kReportFormRoute),
      ('Báo cáo của tôi', kMyReportsRoute),
      ('Admin – hàng đợi báo cáo', kAdminQueueRoute),
      ('Tài khoản bị khoá', kBannedRoute),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('TV4 – Màn hình thử')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final e in entries) ...[
            AppButton(
              label: e.$1,
              kind: AppButtonKind.secondary,
              onPressed: () => Navigator.of(context).pushNamed(e.$2),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
