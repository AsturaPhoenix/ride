import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:http/http.dart' as http;
import 'package:ride_shared/protocol.dart';
import 'package:uri_to_file/uri_to_file.dart';

import 'config.dart';
import 'tesla.dart' as tesla;

enum ServerLifecycleState { stopped, starting, started, stopping, invalid }

class ServerManager extends ChangeNotifier {
  ServerLifecycleState _lifecycleState;
  ServerLifecycleState get lifecycleState => _lifecycleState;

  late final StreamSubscription _stateSubscription;
  ServerState? _serverState;
  ServerState? get serverState => _serverState;
  Object? _lastError;
  Object? get lastError => _lastError;

  ServerManager._(
    this._lifecycleState,
    Stream<ServerState?> stateStream, [
    ServerState? initialState,
  ]) {
    _syncState(initialState);

    _stateSubscription = stateStream.listen(
      (state) {
        _syncState(state);
        notifyListeners();
      },
      onError: (e) {
        _lastError = e;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _stateSubscription.cancel();
    super.dispose();
  }

  void _syncState(ServerState? state) {
    _serverState = state;
    _lastError = null; // defer to serverState.serverErrors
  }

  static Future<ServerManager> initialize() async {
    final service = FlutterBackgroundService();

    if (!await service.configure(
      iosConfiguration: IosConfiguration(),
      androidConfiguration: AndroidConfiguration(
        onStart: Server.main,
        isForegroundMode: true,
        autoStart: false,
        autoStartOnBoot: false,
        initialNotificationTitle: 'RIDE Hub',
        initialNotificationContent: 'Server is running.',
      ),
    )) {
      throw 'Failed to configure background service.';
    }

    final stateStream =
        service.on('syncState').map(ServerState.fromNullableJson);
    if (await service.isRunning()) {
      service.invoke('syncState');
      return ServerManager._(
        ServerLifecycleState.started,
        stateStream,
        await stateStream.first,
      );
    } else {
      return ServerManager._(
        ServerLifecycleState.stopped,
        stateStream,
      );
    }
  }

  Future<void> start() async {
    if (_lifecycleState != ServerLifecycleState.stopped &&
        _lifecycleState != ServerLifecycleState.invalid) {
      throw StateError('state must be stopped or invalid to start');
    }

    // State to fall back to if an operation fails.
    ServerLifecycleState fallbackState = ServerLifecycleState.stopped;

    try {
      _lifecycleState = ServerLifecycleState.starting;
      _lastError = null;
      notifyListeners();

      // After the server starts successfully, it'll send an initial sync.
      // Using a notification listener has the consequence that upon startup,
      // there will be two separate notifications for the initial sync and the
      // state change to ServerLifecycleState.started. There are ways we could
      // work around this, but they're probably not worth it.
      final firstSync = Completer<void>();
      addListener(firstSync.complete);

      if (!await FlutterBackgroundService().startService()) {
        throw 'Failed to start background service.';
      }

      fallbackState = ServerLifecycleState.invalid;

      await firstSync.future;
      removeListener(firstSync.complete);

      _lifecycleState = fallbackState = ServerLifecycleState.started;
      notifyListeners();
    } catch (e) {
      _lifecycleState = fallbackState;
      _lastError = e;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    if (_lifecycleState != ServerLifecycleState.started &&
        _lifecycleState != ServerLifecycleState.invalid) {
      throw StateError('state must be started or invalid to stop');
    }

    // State to fall back to if an operation fails.
    ServerLifecycleState fallbackState = ServerLifecycleState.started;

    try {
      final service = FlutterBackgroundService();

      _lifecycleState = ServerLifecycleState.stopping;
      _lastError = null;
      notifyListeners();

      service.invoke('stop');

      // We'll have to poll for stop.
      const pollInterval = Duration(seconds: 1);
      while (await service.isRunning()) {
        await Future.delayed(pollInterval);
      }

      _syncState(null);

      _lifecycleState = fallbackState = ServerLifecycleState.stopped;
      notifyListeners();
    } catch (e) {
      _lifecycleState = fallbackState;
      _lastError = e;
      notifyListeners();
    }
  }

  void pushAssets() => FlutterBackgroundService().invoke('pushAssets');
  void wake([List<String>? ids]) => _send(['wake'], ids);
  void home([List<String>? ids]) => _send(['home'], ids);
  void sleep([List<String>? ids]) => _send(['sleep'], ids);
  void updateVehicle() => FlutterBackgroundService().invoke('updateVehicle');

  static void _send(Message message, List<String>? ids) =>
      FlutterBackgroundService().invoke('send', {
        'message': message,
        'ids': ids,
      });
}

class ServerErrors {
  Object? assets;
  Object? general;

  ServerErrors({this.assets, this.general});
  ServerErrors.fromJson(Map<String, dynamic> map)
      : assets = map['assets'],
        general = map['general'];

  Map<String, dynamic> toJson() => {
        'assets': assets?.toString(),
        'general': general?.toString(),
      };
}

class ServiceTeslaRemote implements tesla.ClientRemote {
  int _sequenceNumber = 0;
  final _calls = <int, Completer<Map<String, dynamic>>>{};
  late final StreamSubscription _subscription;

  ServiceTeslaRemote() {
    _subscription = FlutterBackgroundService().on('teslaApi').listen((event) {
      final {
        'sequenceNumber': int sequenceNumber,
        'response': Map<String, dynamic> response,
      } = event!;

      _calls.remove(sequenceNumber)!.complete(response);
    });
  }

  @override
  Future<Map<String, dynamic>> call(
    String endpoint,
    Map<String, dynamic> queryParameters,
  ) async {
    final completer = Completer<Map<String, dynamic>>();
    final sequenceNumber = _sequenceNumber++;

    _calls[sequenceNumber] = completer;
    FlutterBackgroundService().invoke('teslaApi', {
      'sequenceNumber': sequenceNumber,
      'endpoint': endpoint,
      'queryParameters': queryParameters,
    });

    return completer.future;
  }

  @override
  void close() {
    _subscription.cancel();
    _calls.clear();
  }
}

class DeviceState {
  bool hasAssets;
  String? foregroundPackage;
  bool? screenOn;

  DeviceState({required this.hasAssets, this.foregroundPackage, this.screenOn});
}

class ServerState {
  static ServerState? fromNullableJson(Map<String, dynamic>? map) =>
      map == null ? null : ServerState.fromJson(map);

  final int port;
  final Map<String, DeviceState> connections;
  final ServerErrors lastErrors;

  const ServerState({
    required this.port,
    required this.connections,
    required this.lastErrors,
  });

  ServerState.fromJson(Map<String, dynamic> map)
      : this(
          port: map['port'] as int,
          connections: {
            for (final MapEntry(key: id, value: connection)
                in (map['connections'] as Map).entries)
              id as String: DeviceState(
                hasAssets: connection['hasAssets'] as bool,
                foregroundPackage: connection['foregroundPackage'] as String?,
                screenOn: connection['screenOn'] as bool?,
              ),
          },
          lastErrors:
              ServerErrors.fromJson(map['lastErrors'] as Map<String, dynamic>),
        );

  // flutter background service uses a JSON codec
  Map<String, dynamic> toJson() => {
        'port': port,
        'connections': {
          for (final MapEntry(key: id, value: connection)
              in connections.entries)
            id: {
              'hasAssets': connection.hasAssets,
              'foregroundPackage': connection.foregroundPackage,
              'screenOn': connection.screenOn,
            },
        },
        'lastErrors': lastErrors.toJson(),
      };
}

class ServerConnectionInfo {
  bool hasAssets;
  String id;
  String? foregroundPackage;
  bool? screenOn;

  ServerConnectionInfo({
    required this.hasAssets,
    required this.id,
    this.foregroundPackage,
    this.screenOn,
  });
}

Future<Uint8List> fetchResource(String resource) async {
  try {
    return (await toFile(resource)).readAsBytes();
  } on Exception {
    final uri = Uri.parse(resource);
    final response = await http.get(uri);
    if (response.statusCode == HttpStatus.ok) {
      return response.bodyBytes;
    } else {
      throw HttpException(response.toString(), uri: uri);
    }
  } finally {
    clearTemporaryFiles();
  }
}

class Server extends ChangeNotifier {
  @pragma('vm:entry-point')
  static Future<void> main(ServiceInstance service) async {
    try {
      final config = await Config.load();
      final serverSocket =
          await ServerSocket.bind(InternetAddress.anyIPv4, config.serverPort);
      final server = Server(config, serverSocket);

      void syncState() {
        service.invoke(
          'syncState',
          ServerState(
            port: server.serverSocket.port,
            connections: {
              for (final connection in server.connections.values)
                connection.id: DeviceState(
                  hasAssets: connection.hasAssets,
                  foregroundPackage: connection.foregroundPackage,
                  screenOn: connection.screenOn,
                ),
            },
            lastErrors: server.lastErrors,
          ).toJson(),
        );
      }

      server.addListener(syncState);
      // Send initial state for the actual port number, if configured as 0.
      syncState();

      final subscriptions = [
        service.on('syncState').listen((_) => syncState()),
        service.on('pushAssets').listen((_) => server.pushAssets()),
        service.on('updateVehicle').listen((_) => server.updateVehicle()),
        service.on('send').listen(
              (args) => server.send(
                args!['message'] as Message,
                args['ids'] as Iterable<String>?,
              ),
            ),
        service.on('teslaApi').listen((args) async {
          final {
            'sequenceNumber': int sequenceNumber,
            'endpoint': String endpoint,
            'queryParameters': Map<String, dynamic> queryParameters,
          } = args!;

          final response = server.teslaClient == null
              ? {'error': 'Not connected.'}
              : await server.teslaClient!.remote
                  .call(endpoint, queryParameters);

          service.invoke('teslaApi', {
            'sequenceNumber': sequenceNumber,
            'response': response,
          });
        }),
      ];
      await service.on('stop').first;

      await Future.wait([
        for (final subscription in subscriptions) subscription.cancel(),
      ]);

      await server.close();
    } finally {
      await service.stopSelf();
    }
  }

  final Config config;
  final ServerSocket serverSocket;
  final Map<Sink<Message>, ServerConnectionInfo> connections = {};
  final lastErrors = ServerErrors();

  Server(this.config, this.serverSocket) {
    void onError(Object e) {
      lastErrors.general = e;
      notifyListeners();
    }

    serverSocket.listen(
      (socket) async {
        socket.setOption(SocketOption.tcpNoDelay, true);

        // ignore: close_sinks
        final sink = encoder.startChunkedConversion(socket);
        connections[sink] = ServerConnectionInfo(
          hasAssets: false,
          id: socket.remoteAddress.address,
        );
        notifyListeners();

        // Listen for incoming messages from the client
        socket.transform(decoder).listen(
          (message) => _dispatch(sink, message),
          onError: onError,
          onDone: () {
            connections.remove(sink);
            notifyListeners();
          },
        );
      },
      onError: onError,
    );

    updateVehicle();
  }

  Future<void> close() async {
    await serverSocket.close();
    dispose();
  }

  void _dispatch(Sink<Message> connection, Message args) {
    lastErrors.general = null;
    notifyListeners();

    try {
      switch (args) {
        case ['id', final String value]:
          connections[connection]!.id = value;
          notifyListeners();
          break;
        case ['assets', final String? assetsVersion]:
          if (assetsVersion == config.assetsVersion) {
            connections[connection]!.hasAssets = true;
            notifyListeners();
          } else {
            pushAssets(connection);
          }
          break;
        case ['window', final String foregroundPackage]:
          connections[connection]!.foregroundPackage = foregroundPackage;
          notifyListeners();
          break;
        case ['screen', final bool screenOn]:
          connections[connection]!.screenOn = screenOn;
          notifyListeners();
          break;
      }
    } catch (e) {
      lastErrors.general = e;
      notifyListeners();
    }
  }

  Future<Uint8List>? assetsFetch;

  Future<void> pushAssets([Sink<Message>? connection]) async {
    lastErrors.assets = null;
    notifyListeners();

    try {
      // Reload config in case the assets changed.
      await config.reload();

      if (config.assets != null) {
        assetsFetch ??= () async {
          try {
            final assets = await fetchResource(config.assets!);
            config.assetsVersion = computeAssetsVersion(assets);
            return assets;
          } finally {
            assetsFetch = null;
          }
        }();

        final assets = await assetsFetch!;
        final connections = connection == null
            ? this.connections
            : {connection: this.connections[connection]!};

        for (final MapEntry(key: connection, value: connectionInfo)
            in connections.entries) {
          // This will be set to true when the remote device acknowledges the
          // latest assets version.
          connectionInfo.hasAssets = false;

          connection.add(['assets', assets]);
        }

        notifyListeners();
      }
    } catch (e) {
      lastErrors.assets = e;
      notifyListeners();
    }
  }

  List<Sink<Message>> findConnections(Set<String> ids) => [
        for (final MapEntry(key: connection, value: ServerConnectionInfo(:id))
            in connections.entries)
          if (ids.contains(id)) connection,
      ];

  void send(Message message, [Iterable<String>? ids]) {
    lastErrors.general = null;
    notifyListeners();

    try {
      for (final connection
          in ids == null ? connections.keys : findConnections({...ids})) {
        connection.add(message);
      }
    } catch (e) {
      lastErrors.general = e;
      notifyListeners();
    }
  }

  tesla.Client? teslaClient;
  tesla.Vehicle? vehicle;

  Future<void> updateVehicle() async {
    lastErrors.general = null;
    notifyListeners();

    try {
      await config.reload();

      if (config.teslaCredentials == null) {
        teslaClient?.close();
        teslaClient = null;
        vehicle = null;
      } else if ((teslaClient?.remote as tesla.Oauth2ClientRemote?)
              ?.client
              .credentials
              .toJson() !=
          config.teslaCredentials) {
        teslaClient?.close();
        teslaClient = tesla.Client.oauth2(config);
        vehicle = tesla.Vehicle(teslaClient!, config.vehicleId!);
      } else if (vehicle?.id != config.vehicleId) {
        vehicle = teslaClient == null
            ? null
            : tesla.Vehicle(teslaClient!, config.vehicleId!);
      }
    } catch (e) {
      lastErrors.general = e;
      notifyListeners();
    }
  }
}
