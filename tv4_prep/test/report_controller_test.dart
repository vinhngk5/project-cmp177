import 'dart:async';

import 'package:test/test.dart';
import 'package:tv4_prep/tv4_prep.dart';

import 'test_support.dart';

const String _product = 'prd_new';

ReportController makeController(FakeReportRepository repo) {
  final c = ReportController(productId: _product, repository: repo);
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('validate phía client', () {
    test('thiếu lý do: báo lỗi, không gọi API, giữ input', () async {
      final repo = FakeReportRepository();
      final c = makeController(repo);

      final ok = await c.submit(null, 'mo ta');

      expect(ok, isFalse);
      expect(c.state.status, ReportSubmitStatus.error);
      expect(c.state.errorMessage, validateReport(reason: null));
      expect(c.state.description, 'mo ta');
      expect(repo.createCalls, 0);
    });

    test('lý do OTHER cần mô tả tối thiểu 10 ký tự', () async {
      final repo = FakeReportRepository();
      final c = makeController(repo);

      final ok = await c.submit(ReportReason.other, 'ngan');

      expect(ok, isFalse);
      expect(c.state.reason, ReportReason.other);
      expect(c.state.errorMessage,
          validateReport(reason: ReportReason.other, description: 'ngan'));
      expect(repo.createCalls, 0);
    });

    test('mô tả quá 500 ký tự bị chặn', () async {
      final repo = FakeReportRepository();
      final c = makeController(repo);

      final ok = await c.submit(
        ReportReason.scam,
        'a' * (kReportDescriptionMaxLength + 1),
      );

      expect(ok, isFalse);
      expect(repo.createCalls, 0);
    });
  });

  group('gửi thành công', () {
    test('idle -> submitting -> success, gửi mô tả đã trim', () async {
      final repo = FakeReportRepository();
      final c = makeController(repo);
      final seen = <ReportSubmitStatus>[];
      final sub = c.states.listen((s) => seen.add(s.status));

      expect(c.state.status, ReportSubmitStatus.idle);
      final ok = await c.submit(ReportReason.scam, '  hang gia  ');
      await pump();

      expect(ok, isTrue);
      expect(seen, [ReportSubmitStatus.submitting, ReportSubmitStatus.success]);
      expect(c.state.status, ReportSubmitStatus.success);
      expect(c.state.report, isNotNull);
      expect(c.state.report!.productId, _product);
      expect(c.state.report!.status, ReportStatus.pending);
      expect(repo.lastDescription, 'hang gia');
      expect(repo.lastReason, ReportReason.scam);
      await sub.cancel();
    });

    test('mô tả trống gửi null', () async {
      final repo = FakeReportRepository();
      final c = makeController(repo);

      await c.submit(ReportReason.spam, '   ');

      expect(repo.lastDescription, isNull);
      expect(c.state.isSuccess, isTrue);
    });

    test('sau khi thành công không gửi lại; reset() mới cho form mới', () async {
      final repo = FakeReportRepository();
      final c = makeController(repo);

      expect(await c.submit(ReportReason.fake, null), isTrue);
      expect(await c.submit(ReportReason.fake, null), isFalse);
      expect(repo.createCalls, 1);

      c.reset();
      expect(c.state.status, ReportSubmitStatus.idle);
    });
  });

  group('khóa khi đang gửi (AC-REPORT-06)', () {
    test('bấm hai lần liên tiếp chỉ gửi một request', () async {
      final repo = FakeReportRepository();
      final gate = Completer<void>();
      repo.gate = gate;
      final c = makeController(repo);

      final first = c.submit(ReportReason.fake, 'x');
      expect(c.state.isSubmitting, isTrue);
      final second = await c.submit(ReportReason.fake, 'x');

      expect(second, isFalse);
      expect(repo.createCalls, 1);

      gate.complete();
      expect(await first, isTrue);
      expect(repo.createCalls, 1);
      expect(c.state.status, ReportSubmitStatus.success);
    });
  });

  group('lỗi từ server: giữ nguyên input, hiện thông báo tiếng Việt', () {
    test('409 REPORT_ALREADY_PENDING', () async {
      final repo = FakeReportRepository()..forceAlreadyPending = true;
      final c = makeController(repo);

      final ok = await c.submit(ReportReason.misleading, 'sai mo ta');

      expect(ok, isFalse);
      expect(c.state.status, ReportSubmitStatus.error);
      expect(c.state.errorMessage, kMsgAlreadyReported);
      expect(c.state.errorCode, 'REPORT_ALREADY_PENDING');
      expect(c.state.alreadyPending, isTrue);
      expect(c.state.reason, ReportReason.misleading);
      expect(c.state.description, 'sai mo ta');
    });

    test('báo cáo lại Product đã có report PENDING (dữ liệu mẫu)', () async {
      final repo = FakeReportRepository();
      final c = ReportController(
        productId: 'prd_01JPRODUCT1',
        repository: repo,
      );
      addTearDown(c.dispose);

      await c.submit(ReportReason.misleading, null);

      expect(c.state.alreadyPending, isTrue);
      expect(c.state.errorMessage, kMsgAlreadyReported);
    });

    test('429 REPORT_RATE_LIMITED kèm Retry-After', () async {
      final repo = FakeReportRepository()
        ..forceRateLimited = true
        ..rateLimitRetryAfter = const Duration(minutes: 30);
      final c = makeController(repo);

      await c.submit(ReportReason.spam, 'spam');

      expect(c.state.status, ReportSubmitStatus.error);
      expect(c.state.errorMessage, kMsgReportRateLimited);
      expect(c.state.errorCode, 'REPORT_RATE_LIMITED');
      expect(c.state.retryAfter, const Duration(minutes: 30));
    });

    test('429 với mã lạ vẫn hiện thông báo quá hạn mức báo cáo', () async {
      final repo = FakeReportRepository();
      repo.faults.failOnce(ApiException(httpStatus: 429, code: 'RATE_LIMITED'));
      final c = makeController(repo);

      await c.submit(ReportReason.spam, null);

      expect(c.state.errorMessage, kMsgReportRateLimited);
    });

    test('hạn mức tự nhiên: vượt dailyLimit thì 429', () async {
      final repo = FakeReportRepository(seed: false)..dailyLimit = 1;
      final c1 = ReportController(productId: 'prd_a', repository: repo);
      final c2 = ReportController(productId: 'prd_b', repository: repo);
      addTearDown(c1.dispose);
      addTearDown(c2.dispose);

      expect(await c1.submit(ReportReason.spam, null), isTrue);
      expect(await c2.submit(ReportReason.spam, null), isFalse);
      expect(c2.state.errorMessage, kMsgReportRateLimited);
    });

    test('offline: giữ form, thử lại được và không tạo trùng', () async {
      final repo = FakeReportRepository();
      repo.faults.offline = true;
      final c = makeController(repo);

      expect(await c.submit(ReportReason.fake, 'giong hang that'), isFalse);
      expect(c.state.errorMessage, kMsgOffline);
      expect(c.state.reason, ReportReason.fake);
      expect(c.state.description, 'giong hang that');
      expect(repo.reports.where((r) => r.productId == _product), isEmpty);

      repo.faults.offline = false;
      expect(await c.submit(ReportReason.fake, 'giong hang that'), isTrue);
      expect(repo.reports.where((r) => r.productId == _product), hasLength(1));
    });

    test('lỗi không phải ApiException: thông báo chung, không lộ chi tiết',
        () async {
      final repo = _ThrowingReportRepository();
      final c = ReportController(productId: _product, repository: repo);
      addTearDown(c.dispose);

      await c.submit(ReportReason.spam, null);

      expect(c.state.status, ReportSubmitStatus.error);
      expect(c.state.errorMessage, kMsgGeneric);
    });
  });
}

class _ThrowingReportRepository implements ReportRepository {
  @override
  Future<MyReport> createReport(
    String productId,
    ReportReason reason,
    String? description,
  ) async {
    throw StateError('boom: chi tiet ky thuat');
  }

  @override
  Future<PageResult<MyReport>> myReports(int page, {int pageSize = 20}) =>
      throw UnimplementedError();

  @override
  Future<MyReport> myReport(String id) => throw UnimplementedError();
}
