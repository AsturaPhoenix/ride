import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:async/async.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:retry/retry.dart';
import 'package:ride_shared/protocol.dart';

import 'config.dart';

enum ClientStatus { disconnected, connecting, connected }

class ClientManager extends ChangeNotifier {
  final Config config;

  StreamSubscription? _subscription;
  CancelableOperation<void>? _connectionTask;
  Client? _client;
  Client? get client => _client;
  ClientStatus get status {
    assert(_connectionTask == null || !_connectionTask!.isCanceled);
    assert(_client == null || _client!.isConnected);

    return _client != null
        ? ClientStatus.connected
        : _connectionTask != null
            ? ClientStatus.connecting
            : ClientStatus.disconnected;
  }

  ClientManager(this.config);

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  CancelableOperation<void> _maintainConnection() =>
      Client.connectWithRetry(config).thenOperation(
        (client, completer) async {
          _client = client;
          notifyListeners();
          await client.disconnected;
          _client = null;
          notifyListeners();
          if (!completer.isCanceled) {
            completer.completeOperation(_maintainConnection());
          }
        },
        onCancel: (completer) => _client?.close(),
      );

  void start() {
    _subscription ??=
        Connectivity().onConnectivityChanged.listen((connectivityResult) async {
      _subscription!.pause();

      await _connectionTask?.cancel();
      _connectionTask = null;

      if (connectivityResult == ConnectivityResult.wifi) {
        _connectionTask = _maintainConnection();
      }

      notifyListeners();

      _subscription!.resume();
    });
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await _connectionTask?.cancel();
    _connectionTask = null;
  }
}

class Client {
  static Future<Client> connect(
    Config config, [
    dynamic host,
    int? port,
  ]) async {
    host ??= await NetworkInfo().getWifiGatewayIP();
    port ??= config.serverPort;

    return Client(config: config, socket: await Socket.connect(host, port));
  }

  static CancelableOperation<Client> connectWithRetry(Config config) {
    final completer = CancelableCompleter<Client>();
    completer.complete(() async {
      final client = await retry(
        () => connect(config),
        retryIf: (_) => !completer.isCanceled,
      );
      if (completer.isCanceled) {
        client.close();
      }
      return client;
    }());
    return completer.operation;
  }

  final Config config;
  final Sink<Message> _socket;

  void Function()? onAssetsReceived;

  final _disconnected = Completer<void>();
  bool get isConnected => !_disconnected.isCompleted;
  Future<void> get disconnected => _disconnected.future;

  Client({required this.config, required Socket socket, this.onAssetsReceived})
      : _socket = encoder.startChunkedConversion(socket) {
    socket.transform(decoder).listen(_dispatch, onDone: _disconnected.complete);

    _send(['id', config.id]);
    _send(['assets', config.assetsVersion]);
  }

  void close() => _socket.close();

  Future<void> _dispatch(Message args) async {
    switch (args.first) {
      case 'id':
        config.id = args[1] as String;
        _send(['id', config.id]);
        break;
      case 'assets':
        final assets = args[1] as Uint8List;

        final archive = ZipDecoder().decodeBytes(assets, verify: true);
        final path = await Config.getAssetsPath();
        try {
          await Directory(path).delete(recursive: true);
        } on PathNotFoundException {
          // ignore
        }
        await extractArchiveToDiskAsync(archive, path);

        config.assetsVersion = computeAssetsVersion(assets);
        _send(['assets', config.assetsVersion]);
        break;
    }
  }

  void _send(List<dynamic> args) => _socket.add(args);
}
