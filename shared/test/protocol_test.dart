import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:ride_shared/protocol.dart';
import 'package:test/test.dart';

void main() {
  test('codec roundtrip', () {
    const message = [
      'method',
      {
        'number': 42,
        'string': 'abcd',
      }
    ];

    expect(decoder.convert(encoder.convert(message)), message);
  });

  group('socket integration', () {
    late ServerSocket serverSocket;
    late Socket client, server;

    setUp(() async {
      serverSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(serverSocket.close);

      await Future.wait([
        () async {
          client = await Socket.connect(
              InternetAddress.loopbackIPv4, serverSocket.port);
          addTearDown(client.close);
        }(),
        () async {
          server = await serverSocket.first;
          addTearDown(server.close);
        }(),
      ]);
    });

    test('small messages', () async {
      const messages = [
        ['thing one'],
        ['thing two'],
      ];

      final clientEncoder = encoder.startChunkedConversion(client);
      messages.forEach(clientEncoder.add);
      clientEncoder.close();

      expect(server.transform(decoder), emitsInOrder(messages));
    });

    test('large message', () async {
      final message = [
        'method',
        {
          'number': 42,
          'string': 'abcd' * 40000,
        }
      ];

      encoder.startChunkedConversion(client)
        ..add(message)
        ..close();
      expect(server.transform(decoder), emits(message));
    });
  });

  test('diffMessages', () {
    expect(
        diffMessages({
          'volume': {
            'setting': 0.0,
            'meta': {'max': 10.0, 'step': 1.0}
          }
        }, {
          'volume': {
            'setting': null,
            'meta': {'max': 10.0, 'step': 1.0}
          }
        }),
        {
          'volume': {'setting': null}
        });
  });

  group('model link', () {
    const shadow = Duration(seconds: 20);

    test('initialize from upstream', () {
      final model = ModelLink(shadow);
      model.fromUpstream(42);
      expect(model.value, 42);
    });

    test('initialize from donwstream', () {
      final model = ModelLink(shadow);
      model.fromDownstream(42);
      expect(model.value, 42);
    });

    test(
        'downstream shadows upstream',
        () => fakeAsync((async) {
              final model = ModelLink(shadow);
              model
                ..fromDownstream(42)
                ..fromUpstream(56);
              expect(model.value, 42);

              async.elapse(shadow - const Duration(milliseconds: 1));
              model.fromUpstream(13);
              expect(model.value, 42);

              async.elapse(const Duration(milliseconds: 1));
              model.fromUpstream(0);
              expect(model.value, 0);
            }));

    test(
        'downstream updates reset shadow',
        () => fakeAsync((async) {
              final model = ModelLink(shadow);
              model.fromDownstream(42);

              async.elapse(shadow ~/ 2);
              model.fromDownstream(42);

              async.elapse(shadow - const Duration(milliseconds: 1));
              model.fromUpstream(56);
              expect(model.value, 42);

              async.elapse(const Duration(milliseconds: 1));
              model.fromUpstream(0);
              expect(model.value, 0);
            }));

    test(
        'upstream does not shadow downstream',
        () => fakeAsync((async) {
              final model = ModelLink(shadow);
              model
                ..fromUpstream(42)
                ..fromDownstream(56);
              expect(model.value, 56);
            }));

    test('downstream does not shadow itself', () {
      final model = ModelLink(shadow);
      model
        ..fromDownstream(42)
        ..fromDownstream(56);
      expect(model.value, 56);
    });
  });
}
