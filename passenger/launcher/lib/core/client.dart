import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:async/async.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:overlay_window/overlay_window.dart';
import 'package:retry/retry.dart';
import 'package:ride_device_policy/ride_device_policy.dart';
import 'package:ride_shared/protocol.dart';
import 'package:screen_state/screen_state.dart';

import '../ui/vehicle_controls.dart';
import 'config.dart';

enum ClientStatus {
  disconnected,
  connecting,
  connected;

  static ClientStatus fromJson(dynamic value) => values[value as int];
  int toJson() => index;
}

abstract class ClientListener {
  void assetsChanged();
}

typedef ClientEvents = ({
  Stream<ClientManagerState>? state,
  Stream? assets,
});

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
      state: service
          .on('syncState')
          .map((event) => ClientManagerState.fromJson(event!)),
      assets: service.on('assets'),
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
  final VehicleState vehicle;

  late final Iterable<StreamSubscription> _subscriptions;

  ClientManager({
    this.listener,
    ClientStatus initialStatus = ClientStatus.disconnected,
    ClientEvents? streams,
  })  : _status = initialStatus,
        vehicle = VehicleState() {
    _subscriptions = [
      streams?.state?.listen((state) {
        _status = state.status;
        if (state.vehicle != null) {
          vehicle.fromJson(state.vehicle!, UpdateDirection.fromUpstream);
        }
        notifyListeners();
      }),
      streams?.assets?.listen((_) => listener?.assetsChanged()),
    ].nonNulls;
  }

  @override
  void dispose() {
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

  void setTemperature(double value) {
    FlutterBackgroundService().invoke('setTemperature', {'value': value});
  }

  void setVolume(double value) {
    FlutterBackgroundService().invoke('setVolume', {'value': value});
  }

  void showOverlays(bool show) {
    FlutterBackgroundService().invoke('showOverlays', {'visible': show});
  }
}

class _ServiceListener implements ClientListener {
  final ServiceInstance service;

  _ServiceListener(this.service);

  @override
  void assetsChanged() => service.invoke('assets');
}

class ClientManagerState {
  final ClientStatus status;
  final Map<String, dynamic>? vehicle;

  const ClientManagerState({required this.status, this.vehicle});

  ClientManagerState.fromJson(Map<String, dynamic> map)
      : this(
          status: ClientStatus.fromJson(map['status']),
          vehicle: map['vehicle'] as Map<String, dynamic>?,
        );

  Map<String, dynamic> toJson() => {
        'status': status.toJson(),
        'vehicle': vehicle,
      };
}

class Client extends ChangeNotifier {
  @pragma('vm:entry-point')
  static Future<void> main(ServiceInstance service) async {
    try {
      // Start by releasing the device policy in case of previous unclean
      // shutdown.
      await releaseDevicePolicy();

      final listener = _ServiceListener(service);
      final config = await Config.load();

      ClientStatus status = ClientStatus.disconnected;

      void setStatus(ClientStatus value) {
        status = value;
        service.invoke(
          'syncState',
          ClientManagerState(status: value).toJson(),
        );
      }

      Client? client;
      CancelableOperation<void>? connectionTask;

      CancelableOperation<void> maintainConnection() =>
          Client.connectWithRetry(config).thenOperation(
            (newClient, completer) async {
              newClient.listener = listener;

              client = newClient;
              setStatus(ClientStatus.connected);

              newClient.addListener(
                () => service.invoke(
                  'syncState',
                  ClientManagerState(
                    status: status,
                    vehicle: newClient.vehicle.toJson(),
                  ).toJson(),
                ),
              );

              await newClient.disconnected;
              newClient.dispose();
              client = null;
              setStatus(ClientStatus.disconnected);

              if (!completer.isCanceled) {
                completer.completeOperation(maintainConnection());
              }
            },
            onCancel: (completer) => client?.close(),
          );

      final overlayWindows = [
        OverlayWindow.create(
          TemperatureControls.main,
          const WindowParams(
            flags: Flag.notFocusable | Flag.notTouchModal | Flag.layoutNoLimits,
            gravity: Gravity.bottom | Gravity.left,
            y: -48,
            width: 192,
            height: 48,
          ),
        ),
        OverlayWindow.create(
          VolumeControls.main,
          const WindowParams(
            flags: Flag.notFocusable | Flag.notTouchModal | Flag.layoutNoLimits,
            gravity: Gravity.bottom | Gravity.right,
            y: -48,
            width: 192,
            height: 48,
          ),
        ),
      ];

      final subscriptions = [
        service.on('syncState').listen((_) {
          service.invoke(
            'syncState',
            ClientManagerState(
              status: status,
              vehicle: client?.vehicle.toJson(),
            ).toJson(),
          );
        }),
        Connectivity().onConnectivityChanged.listen((connectivityResult) async {
          await connectionTask?.cancel();
          connectionTask = null;

          if (connectivityResult == ConnectivityResult.wifi) {
            connectionTask = maintainConnection();
            setStatus(ClientStatus.connecting);
          } else {
            setStatus(ClientStatus.disconnected);
          }
        }),
        service.on('setTemperature').listen((args) {
          client?.setTemperature((args!['value'] as num).toDouble());
        }),
        service.on('setVolume').listen((args) {
          client?.setVolume((args!['value'] as num).toDouble());
        }),
        service.on('showOverlays').listen((args) {
          final visibility = args!['visible'] as bool
              ? OverlayWindow.visible
              : OverlayWindow.gone;
          for (final overlayWindow in overlayWindows) {
            (() async => (await overlayWindow).setVisibility(visibility))();
          }
        }),
      ];

      await service.on('stop').first;

      await Future.wait([
        for (final subscription in subscriptions) subscription.cancel(),
        for (final overlayWindow in overlayWindows)
          (() async => (await overlayWindow).destroy())(),
      ]);
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
        delayFactor: const Duration(seconds: 1),
        randomizationFactor: 0.0,
        maxDelay: const Duration(seconds: 15),
        maxAttempts: -1 >>> 1,
      );
      if (completer.isCanceled) {
        client.close();
      }
      return client;
    }());
    return completer.operation;
  }

  static Future<void> applyDevicePolicy() =>
      RideDevicePolicy.setScreenOffTimeout(const Duration(days: 1));

  static Future<void> releaseDevicePolicy() =>
      RideDevicePolicy.setScreenOffTimeout(const Duration(minutes: 2));

  final Config config;
  final Sink<Message> _socket;
  ClientListener? listener;

  void Function()? onAssetsReceived;

  final _disconnected = Completer<void>();
  bool get isConnected => !_disconnected.isCompleted;
  Future<void> get disconnected => _disconnected.future;

  late final StreamSubscription _windowEventSubscription, _screenSubscription;

  final VehicleState vehicle = VehicleState(const Duration(seconds: 2));

  Client({
    required this.config,
    required Socket socket,
    this.onAssetsReceived,
    this.listener,
  }) : _socket = encoder.startChunkedConversion(socket) {
    socket.setOption(SocketOption.tcpNoDelay, true);

    socket.transform(decoder).listen(_dispatch, onDone: _disconnected.complete);

    _send(['id', config.id]);
    _send(['assets', config.assetsVersion]);
    _send(['vehicle']);

    applyDevicePolicy();

    _windowEventSubscription = RideDevicePolicy.windowEvents
        .listen((event) => _send(['window', event]));
    _screenSubscription = Screen().screenStateStream!.listen(
      (event) {
        switch (event) {
          case ScreenStateEvent.SCREEN_ON:
            _send(['screen', true]);
            break;
          case ScreenStateEvent.SCREEN_OFF:
            _send(['screen', false]);
            break;
          default:
        }
      },
    );
  }

  void close() {
    _windowEventSubscription.cancel();
    _screenSubscription.cancel();
    _socket.close();
    releaseDevicePolicy();
  }

  Future<void> _dispatch(Message args) async {
    switch (args) {
      case ['id', final value as String]:
        config.id = value;
        _send(['id', config.id]);
      case ['assets', final assets as Uint8List]:
        {
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
        }
      case ['wake']:
        await RideDevicePolicy.wakeUp();
      case ['home']:
        await RideDevicePolicy.home();
        await RideDevicePolicy.wakeUp();
      case ['sleep']:
        await RideDevicePolicy.lockNow();
      case ['vehicle', final data as Map]:
        {
          final oldVolume = vehicle.volume.setting.value;
          vehicle.fromJson(data, UpdateDirection.fromUpstream);
          final newVolume = vehicle.volume.setting.value;
          if (newVolume != oldVolume && newVolume != null) {
            // I think we can ignore gating on the case where max volume
            // changes.
            _syncDeviceVolume();
          }
          notifyListeners();
        }
    }
  }

  void _send(List<dynamic> args) => _socket.add(args);

  void setTemperature(double value) {
    vehicle.climate.setting.fromDownstream(value);
    notifyListeners();
    _send([
      'vehicle',
      {'temperature': value},
    ]);
  }

  void setVolume(double value) {
    vehicle.volume.setting.fromDownstream(value);
    notifyListeners();
    _send([
      'vehicle',
      {'volume': value},
    ]);
    _syncDeviceVolume();
  }

  Future<void> _syncDeviceVolume() async {
    final value = vehicle.volume.setting.value, max = vehicle.volume.meta.max;
    if (value != null && max != null) {
      await RideDevicePolicy.setVolume(value / max);
    }
  }
}
