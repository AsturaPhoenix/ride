import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:async/async.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:retry/retry.dart';
import 'package:ride_shared/protocol.dart';

import 'config.dart';

enum ClientStatus { disconnected, connecting, connected }

abstract class ClientListener {
  void assetsChanged();
}

typedef ClientEvents = ({Stream<ClientState>? state, Stream? assetsChanged});

class ClientManager extends ChangeNotifier {
  static Future<ClientManager> initialize() async {
    final service = FlutterBackgroundService();

    if (!await service.configure(
      iosConfiguration: IosConfiguration(),
      androidConfiguration: AndroidConfiguration(
        onStart: Client.main,
        isForegroundMode: true,
        autoStart: false,
        autoStartOnBoot: false,
        initialNotificationTitle: 'RIDE Launcher',
        initialNotificationContent: 'Client is running.',
      ),
    )) {
      throw 'Failed to configure background service.';
    }

    final streams = (
      state:
          service.on('syncState').map((event) => ClientState.fromJson(event!)),
      assetsChanged: service.on('assetsChanged'),
    );
    if (await service.isRunning()) {
      service.invoke('syncState');
      return ClientManager(
        initialStatus: (await streams.state.first).status,
        streams: streams,
      );
    } else {
      return ClientManager(streams: streams);
    }
  }

  ClientListener? listener;

  ClientStatus _status;
  ClientStatus get status => _status;

  final ClientEvents? streams;
  late final Iterable<StreamSubscription> _subscriptions;

  ClientManager({
    this.listener,
    ClientStatus initialStatus = ClientStatus.disconnected,
    this.streams,
  }) : _status = initialStatus {
    _subscriptions = [
      streams?.state?.listen((state) {
        _status = state.status;
        notifyListeners();
      }),
      streams?.assetsChanged?.listen((_) => listener?.assetsChanged()),
    ].nonNulls;
  }

  @override
  void dispose() {
    stop();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  Future<void> start() async {
    if (!await FlutterBackgroundService().startService()) {
      throw 'Failed to start background service.';
    }
  }

  Future<void> stop() async {
    final service = FlutterBackgroundService();

    service.invoke('stop');

    // We'll have to poll for stop.
    const pollInterval = Duration(seconds: 1);
    while (await service.isRunning()) {
      await Future.delayed(pollInterval);
    }
  }
}

class _ServiceListener implements ClientListener {
  final ServiceInstance service;
  _ServiceListener(this.service);

  @override
  void assetsChanged() => service.invoke('assetsChanged');
}

class ClientState {
  final ClientStatus status;
  const ClientState({required this.status});

  ClientState.fromJson(Map<String, dynamic> map)
      : this(status: ClientStatus.values[map['status'] as int]);

  Map<String, dynamic> toJson() => {'status': status.index};
}

class Client {
  @pragma('vm:entry-point')
  static Future<void> main(ServiceInstance service) async {
    try {
      final listener = _ServiceListener(service);
      final config = await Config.load();

      void setStatus(ClientStatus status) =>
          service.invoke('syncState', ClientState(status: status).toJson());

      Client? client;
      CancelableOperation<void>? connectionTask;

      CancelableOperation<void> maintainConnection() =>
          Client.connectWithRetry(config).thenOperation(
            (newClient, completer) async {
              newClient.listener = listener;

              client = newClient;
              setStatus(ClientStatus.connected);

              await newClient.disconnected;
              client = null;
              setStatus(ClientStatus.disconnected);

              if (!completer.isCanceled) {
                completer.completeOperation(maintainConnection());
              }
            },
            onCancel: (completer) => client?.close(),
          );

      final subscription = Connectivity()
          .onConnectivityChanged
          .listen((connectivityResult) async {
        await connectionTask?.cancel();
        connectionTask = null;

        if (connectivityResult == ConnectivityResult.wifi) {
          connectionTask = maintainConnection();
          setStatus(ClientStatus.connecting);
        } else {
          setStatus(ClientStatus.disconnected);
        }
      });

      await service.on('stop').first;

      await subscription.cancel();
      await connectionTask?.cancel();
    } finally {
      await service.stopSelf();
    }
  }

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
  ClientListener? listener;

  void Function()? onAssetsReceived;

  final _disconnected = Completer<void>();
  bool get isConnected => !_disconnected.isCompleted;
  Future<void> get disconnected => _disconnected.future;

  Client({
    required this.config,
    required Socket socket,
    this.onAssetsReceived,
    this.listener,
  }) : _socket = encoder.startChunkedConversion(socket) {
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

        listener?.assetsChanged();

        config.assetsVersion = computeAssetsVersion(assets);
        _send(['assets', config.assetsVersion]);

        break;
    }
  }

  void _send(List<dynamic> args) => _socket.add(args);
}
