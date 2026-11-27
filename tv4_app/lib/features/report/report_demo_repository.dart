/// Repository dùng cho app tạm: bọc `FakeReportRepository` và bổ sung vài
/// báo cáo đã xử lý để màn "Báo cáo của tôi" có đủ ba trạng thái như Figma.
/// Bỏ file này khi nối API thật.
library;

import 'package:tv4_prep/tv4_prep.dart';

class DemoReportRepository implements ReportRepository {
  DemoReportRepository({FakeReportRepository? fake})
      : fake = fake ?? FakeReportRepository();

  /// Bản fake bên dưới (để bật các công tắc forceAlreadyPending... khi thử tay).
  final FakeReportRepository fake;

  static const _titles = <String, String>{
    'prd_01JPRODUCT1': 'Giáo trình Giải tích 1',
  };

  static final List<MyReport> _extras = <MyReport>[
    MyReport.fromJson({
      'id': 'rpt_demo_resolved',
      'product_id': 'prd_demo_phone',
      'product_title_snapshot': 'Điện thoại Samsung A12',
      'reason': 'SCAM',
      'description': 'Ảnh và mô tả không trùng khớp với sản phẩm.',
      'status': 'RESOLVED',
      'created_at': '2026-11-25T02:10:00Z',
      'resolved_at': '2026-11-26T03:00:00Z',
      'resolution_note': 'Tin đăng đã bị gỡ do thông tin không chính xác.',
    }),
    MyReport.fromJson({
      'id': 'rpt_demo_rejected',
      'product_id': 'prd_demo_bike',
      'product_title_snapshot': 'Xe đạp Giant cũ',
      'reason': 'WRONG_CATEGORY',
      'description': null,
      'status': 'REJECTED',
      'created_at': '2026-11-20T11:45:00Z',
      'resolved_at': '2026-11-21T03:00:00Z',
      'resolution_note': 'Không phát hiện vi phạm.',
    }),
  ];

  /// Bản fake tạo report không có snapshot tiêu đề, còn report seed thì viết
  /// không dấu; điền lại từ bảng tên mẫu có dấu cho đẹp khi xem thử.
  MyReport _withTitle(MyReport r) {
    final title = _titles[r.productId];
    if (title == null) return r;
    return MyReport(
      id: r.id,
      productId: r.productId,
      productTitleSnapshot: title,
      reason: r.reason,
      description: r.description,
      status: r.status,
      createdAt: r.createdAt,
      resolutionNote: r.resolutionNote,
      resolvedAt: r.resolvedAt,
    );
  }

  @override
  Future<MyReport> createReport(
    String productId,
    ReportReason reason,
    String? description,
  ) async =>
      _withTitle(await fake.createReport(productId, reason, description));

  @override
  Future<PageResult<MyReport>> myReports(int page, {int pageSize = 20}) async {
    // Lấy hết phần của fake (tin giả lập ít) rồi gộp với báo cáo mẫu.
    final all = <MyReport>[];
    var p = 1;
    while (true) {
      final r = await fake.myReports(p, pageSize: 100);
      all.addAll(r.items.map(_withTitle));
      if (!r.hasMore) break;
      p++;
    }
    all
      ..addAll(_extras)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final size = pageSize < 1 ? 1 : pageSize;
    final cur = page < 1 ? 1 : page;
    final start = (cur - 1) * size;
    final items = start >= all.length
        ? <MyReport>[]
        : all.sublist(start, (start + size).clamp(0, all.length));
    return PageResult<MyReport>(
      items: items,
      page: cur,
      pageSize: size,
      totalItems: all.length,
      hasMore: cur * size < all.length,
    );
  }

  @override
  Future<MyReport> myReport(String id) async {
    for (final e in _extras) {
      if (e.id == id) return e;
    }
    return _withTitle(await fake.myReport(id));
  }
}
