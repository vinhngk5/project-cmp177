/// Tham số mở form báo cáo (truyền qua `RouteSettings.arguments`).
library;

class ReportFormArgs {
  const ReportFormArgs({
    required this.productId,
    required this.productTitle,
    required this.priceVnd,
  });

  final String productId;
  final String productTitle;
  final int priceVnd;

  /// Sản phẩm mẫu khi mở form từ màn launcher (không có arguments).
  static const ReportFormArgs sample = ReportFormArgs(
    productId: 'prd_01JPRODUCT1',
    productTitle: 'Giáo trình Giải tích 1',
    priceVnd: 45000,
  );
}
