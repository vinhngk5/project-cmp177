import 'package:material_ui/material_ui.dart';
import 'package:tv4_prep/tv4_prep.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'chat_format.dart';
import 'chat_routes.dart';
import 'chat_widgets.dart';

/// Danh sách hội thoại (FR-CHAT-03, FR-CHAT-04).
class ConversationListPage extends StatefulWidget {
  const ConversationListPage({super.key, required this.environment});

  final ChatEnvironment environment;

  @override
  State<ConversationListPage> createState() => _ConversationListPageState();
}

class _ConversationListPageState extends State<ConversationListPage> {
  static const int _pageSize = 20;

  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();

  List<ConversationSummary> _items = const [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  String? _error;
  String _query = '';

  ChatRepository get _repo => widget.environment.repository;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  /// [silent] = làm mới ngầm (kéo để làm mới / quay lại từ phòng chat): giữ
  /// danh sách cũ trên màn hình, lỗi chỉ báo bằng SnackBar.
  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final result = await _repo.listConversations(1, pageSize: _pageSize);
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _page = 1;
        _hasMore = result.hasMore;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (silent) {
        _snack(errorMessageOf(e));
      } else {
        setState(() {
          _loading = false;
          _error = errorMessageOf(e);
        });
      }
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < 240) _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final result = await _repo.listConversations(_page + 1, pageSize: _pageSize);
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...result.items];
        _page += 1;
        _hasMore = result.hasMore;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      _snack(errorMessageOf(e));
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  List<ConversationSummary> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return [
      for (final c in _items)
        if (c.other.displayName.toLowerCase().contains(q) ||
            c.productTitle.toLowerCase().contains(q) ||
            (c.lastMessage?.text.toLowerCase().contains(q) ?? false))
          c,
    ];
  }

  Future<void> _open(ConversationSummary c) async {
    await Navigator.of(context).pushNamed(kChatRoomRoute, arguments: c);
    // Quay lại: cập nhật số chưa đọc / tin cuối.
    if (mounted) _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tin nhắn'), centerTitle: false),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    if (_items.isEmpty) {
      return _refreshable(
        child: const EmptyState(
          icon: Icons.chat_bubble_outline,
          title: 'Chưa có cuộc trò chuyện nào',
          message:
              'Mở một tin đăng và bấm Nhắn tin để bắt đầu trao đổi với người bán.',
        ),
      );
    }

    final visible = _filtered;
    return Column(
      children: [
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Tìm hội thoại',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xoá tìm kiếm',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                    ),
              isDense: true,
              filled: true,
              fillColor: AppColors.bg,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const Divider(),
        Expanded(
          child: visible.isEmpty
              ? _refreshable(
                  child: const EmptyState(
                    icon: Icons.search_off,
                    title: 'Không tìm thấy hội thoại phù hợp',
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _load(silent: true),
                  child: ListView.separated(
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: visible.length + (_loadingMore ? 1 : 0),
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, i) {
                      if (i >= visible.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      final c = visible[i];
                      return _ConversationTile(
                        conversation: c,
                        now: widget.environment.now(),
                        onTap: () => _open(c),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  /// Nội dung không cuộn được (rỗng) vẫn kéo để làm mới được.
  Widget _refreshable({required Widget child}) {
    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: LayoutBuilder(
        builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [SizedBox(height: constraints.maxHeight, child: child)],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.now,
    required this.onTap,
  });

  final ConversationSummary conversation;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final last = c.lastMessage;
    final unread = c.unreadCount > 0;
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InitialsAvatar(name: c.other.displayName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.other.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  unread ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (last != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            formatListTime(last.createdAt, now: now),
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.muted),
                          ),
                        ],
                      ],
                    ),
                    if (c.productTitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          c.productTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.primary),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            last?.text ?? 'Chưa có tin nhắn',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: last == null || !unread
                                  ? AppColors.muted
                                  : AppColors.text,
                              fontWeight:
                                  unread ? FontWeight.w500 : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 8),
                          UnreadBadge(count: c.unreadCount),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
