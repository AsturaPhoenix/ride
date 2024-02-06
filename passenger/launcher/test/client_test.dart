import 'dart:async';

import 'package:async/async.dart';
import 'package:fake_async/fake_async.dart';
import 'package:ride_launcher/core/client.dart';
import 'package:test/fake.dart';
import 'package:test/test.dart';

class Monitor {
  bool complete = false;
  Monitor(Future future) {
    future.then((_) => complete = true);
  }
}

class FakeClient extends Fake implements Client {}

void main() {
  test(
      'Cancel does not complete until connection cancel completes',
      () => fakeAsync((async) {
            final cancelCompleter = Completer<void>();
            final operation = Client.maintainConnection(
                () => Client.connectWithRetry(
                      () => CancelableCompleter<Client>(
                          onCancel: () => cancelCompleter.future).operation,
                    ),
                (_) async {});
            async.flushMicrotasks();

            final cancel = Monitor(operation.cancel());

            async.flushMicrotasks();
            expect(cancel.complete, isFalse);

            cancelCompleter.complete();
            async.flushMicrotasks();
            expect(cancel.complete, isTrue);
          }));

  test(
      'Cancel does not complete until connection handler completes',
      () => fakeAsync((async) {
            final handlerCompleter = Completer<void>();
            final operation = Client.maintainConnection(
                () => CancelableOperation.fromValue(FakeClient()),
                (client) => handlerCompleter.future);
            async.flushMicrotasks();

            final cancel = Monitor(operation.cancel());

            async.flushMicrotasks();
            expect(cancel.complete, isFalse);

            handlerCompleter.complete();
            async.flushMicrotasks();
            expect(cancel.complete, isTrue);
          }));

  test(
      'Does not retry after cancel',
      () => fakeAsync((async) {
            CancelableCompleter<Client>? connectCompleter;
            final operation = Client.maintainConnection(
                () => Client.connectWithRetry(
                      () => (connectCompleter = CancelableCompleter<Client>())
                          .operation,
                    ),
                (_) async {});
            async.flushMicrotasks();

            connectCompleter!.completeError(Exception());
            connectCompleter = null;

            async.elapse(const Duration(seconds: 1));
            assert(connectCompleter == null);
            final cancel = Monitor(operation.cancel());
            async.flushMicrotasks();
            expect(cancel.complete, isTrue);

            async.flushTimers();
            expect(connectCompleter, isNull);
          }));

  test('backpressure', () async {
    final streamController = StreamController();
    Completer? eventCompleter;
    Completer<void>? handlerCompleter;
    listenOnBackpressureBufferOne(streamController.stream, (event) async {
      expect(handlerCompleter, isNull);
      eventCompleter?.complete(event);
      await (handlerCompleter = Completer()).future;
      handlerCompleter = null;
    });

    eventCompleter = Completer();
    streamController.add(0);
    expect(await eventCompleter.future, 0);

    eventCompleter = Completer();
    streamController.add(1);
    await null;
    streamController.add(2);
    await null;
    handlerCompleter!.complete();
    expect(await eventCompleter.future, 2);
  });

  test(
      'Continues if handler throws',
      () => fakeAsync((async) {
            Completer<void>? handlerCompleter;
            Object? error;
            runZonedGuarded(
                () => Client.maintainConnection(
                        () => CancelableOperation.fromValue(FakeClient()),
                        (client) {
                      expect(handlerCompleter, isNull);
                      handlerCompleter = Completer<void>();
                      return handlerCompleter!.future;
                    }),
                (e, _) => error = e);

            async.flushMicrotasks();
            handlerCompleter!.completeError('foo');
            handlerCompleter = null;

            async.flushMicrotasks();
            expect(error, 'foo');
            expect(handlerCompleter, isNotNull);
          }));
}
