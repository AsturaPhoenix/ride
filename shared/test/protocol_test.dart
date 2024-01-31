import 'dart:async';
import 'dart:io';

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
}
