import 'package:fake_async/fake_async.dart';
import 'package:ride_hub/core/tesla.dart';
import 'package:test/test.dart';

void main() {
  const period = Duration(seconds: 1), epsilon = Duration(milliseconds: 1);

  void runTest(
      FakeAsync async,
      List<({bool expect, Duration then, Future<void> Function()? extra})>
          cases) {
    final results = <int>[], expected = <int>[], futures = <Future<void>>[];
    final throttle = Throttle(period);

    for (int i = 0; i < cases.length; ++i) {
      futures.add(throttle.add(() async {
        if (cases[i].extra != null) {
          await cases[i].extra!();
        }
        results.add(i);
      }));
      if (cases[i].expect) {
        expected.add(i);
      }
      async.elapse(cases[i].then);
    }

    expect(results, expected);
    // anyOf(completes, throwsA(anything)) doesn't work.
    expect(Future.wait(futures).catchError((_) => const <Future<void>>[]),
        completes);
    async.flushTimers();
  }

  test(
      'immediate while idle',
      () => fakeAsync((async) =>
          runTest(async, [(expect: true, then: Duration.zero, extra: null)])));

  test(
      'passthrough at boundary',
      () => fakeAsync((async) => runTest(async, [
            (expect: true, then: period, extra: null),
            (expect: true, then: Duration.zero, extra: null),
          ])));

  test(
      'hold under boundary',
      () => fakeAsync((async) {
            runTest(async, [
              (expect: true, then: period - epsilon, extra: null),
              (expect: false, then: Duration.zero, extra: null),
            ]);
            runTest(async, [
              (expect: true, then: period - epsilon, extra: null),
              (expect: true, then: epsilon, extra: null),
            ]);
          }));

  test(
      'drop',
      () => fakeAsync((async) => runTest(async, [
            (expect: true, then: period ~/ 2, extra: null),
            (expect: false, then: period ~/ 2 - epsilon, extra: null),
            (expect: true, then: epsilon, extra: null),
          ])));

  test(
      'long op shadows',
      () => fakeAsync((async) => runTest(async, [
            (
              expect: true,
              then: period,
              extra: () => Future.delayed(period * 2)
            ),
            (expect: false, then: period - epsilon, extra: null),
            (expect: true, then: epsilon, extra: null),
          ])));

  test(
      'continues after exception',
      () => fakeAsync((async) {
            // runTest(async, [
            //   (expect: false, then: period - epsilon, extra: () => throw 'foo'),
            //   (expect: false, then: Duration.zero, extra: null),
            // ]);
            runTest(async, [
              (expect: false, then: period - epsilon, extra: () => throw 'foo'),
              (expect: true, then: epsilon, extra: null),
            ]);
          }));
}
