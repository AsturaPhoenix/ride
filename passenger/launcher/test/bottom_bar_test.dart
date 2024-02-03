import 'package:fake_async/fake_async.dart';
import 'package:ride_launcher/ui/bottom_bar.dart';
import 'package:test/test.dart';

void main() {
  group('eta', () {
    late Eta eta;
    final values = <DateTime?>[];

    setUp(values.clear);
    tearDown(() => eta.dispose());

    void listener() {
      values.add(eta.value);
    }

    test('notifies listeners if changed explicitly', () {
      eta = Eta()..addListener(listener);
      eta.value = DateTime(2023);
      eta.value = DateTime(2024);
      expect(values, [DateTime(2023), DateTime(2024)]);
    });

    test('does not notify listeners if not changed', () {
      eta = Eta()..addListener(listener);
      eta.value = DateTime(2023);
      eta.value = DateTime(2023);
      expect(values, [DateTime(2023)]);
    });

    test(
        'updates every whole minute',
        () => fakeAsync((async) {
              eta = Eta()..addListener(listener);
              final t = DateTime(2023, 1, 1, 0, 0, 50);
              eta.value = t;
              async.elapse(const Duration(seconds: 10));
              expect(values, [t, DateTime(2023, 1, 1, 0, 1, 0)]);
              values.clear();
              async.elapse(const Duration(minutes: 1));
              expect(values, [DateTime(2023, 1, 1, 0, 2, 0)]);
            }));

    test(
        'does not update during cooldown period',
        () => fakeAsync((async) {
              eta = Eta(updateTimeout: const Duration(seconds: 20))
                ..addListener(listener);
              final t = DateTime(2023, 1, 1, 0, 0, 50);
              eta.value = t;
              async.elapse(const Duration(seconds: 15));
              expect(values, [t]);
              values.clear();
              async.elapse(const Duration(seconds: 5));
              expect(values, [DateTime(2023, 1, 1, 0, 1, 10)]);
              values.clear();
              async.elapse(const Duration(seconds: 50));
              expect(values, [DateTime(2023, 1, 1, 0, 2, 0)]);
              values.clear();
              async.elapse(const Duration(minutes: 1));
              expect(values, [DateTime(2023, 1, 1, 0, 3, 0)]);
            }));

    test(
        'resets cooldown even if updated with the same value',
        () => fakeAsync((async) {
              eta = Eta(updateTimeout: const Duration(seconds: 20))
                ..addListener(listener);
              final t = DateTime(2023, 1, 1, 0, 0, 50);
              eta.value = t;
              async.elapse(const Duration(seconds: 15));
              eta.value = t;
              async.elapse(const Duration(seconds: 15));
              expect(values, [t]);
            }));
  });
}
