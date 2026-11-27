import 'dart:async';

/// Nhường event loop vài vòng để mọi microtask / event stream đang chờ chạy xong.
/// Chỉ dùng Duration.zero nên không ngủ thật.
Future<void> pump([int rounds = 6]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Hàm delay giả cho ChatController: ghi lại thời lượng được yêu cầu.
/// - `manual: false` (mặc định): trả về ngay, không ngủ.
/// - `manual: true`: mỗi lần gọi treo cho tới khi test gọi [release].
class FakeDelay {
  FakeDelay({this.manual = false});

  final bool manual;
  final List<Duration> requested = <Duration>[];
  final List<Completer<void>> _waiting = <Completer<void>>[];

  Future<void> call(Duration d) {
    requested.add(d);
    if (!manual) return Future<void>.value();
    final c = Completer<void>();
    _waiting.add(c);
    return c.future;
  }

  int get waiting => _waiting.length;

  /// Cho lần chờ cũ nhất kết thúc.
  void release() => _waiting.removeAt(0).complete();
}

/// Bộ sinh clientMessageId xác định: cid-1, cid-2, ...
class FakeIds {
  int _n = 0;
  String next() => 'cid-${++_n}';
}
