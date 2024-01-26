import 'package:flutter/foundation.dart';
import 'package:ride_shared/defaults.dart' as defaults;

import 'server.dart';

class FakeServerManager extends ChangeNotifier implements ServerManager {
  @override
  Object? lastError;

  @override
  ServerLifecycleState lifecycleState = ServerLifecycleState.stopped;

  @override
  ServerState? serverState;

  @override
  void pushAssets() {}

  @override
  Future<void> start() async {
    lifecycleState = ServerLifecycleState.started;
    serverState = ServerState(
      port: defaults.serverPort,
      connections: {
        'FR': DeviceState(
          hasAssets: true,
          foregroundPackage: null,
          screenOn: null,
        ),
        'RL': DeviceState(
          hasAssets: true,
          foregroundPackage: 'io.baku.ride_launcher',
          screenOn: false,
        ),
        'RR': DeviceState(
          hasAssets: true,
          foregroundPackage: 'com.spotify.music',
          screenOn: true,
        ),
      },
      lastErrors: ServerErrors(),
    );
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    serverState = null;
    lifecycleState = ServerLifecycleState.stopped;
    notifyListeners();
  }

  void _apply(List<String>? ids, void Function(DeviceState) operation) {
    if (serverState == null) return;

    for (final deviceState in ids == null
        ? serverState!.connections.values
        : ids.map((id) => serverState!.connections[id]!)) {
      operation(deviceState);
    }

    notifyListeners();
  }

  @override
  void wake([List<String>? ids]) => _apply(ids, (d) => d.screenOn = true);

  @override
  void home([List<String>? ids]) => _apply(ids, (d) {
        d.foregroundPackage = 'io.baku.ride_launcher';
        d.screenOn = true;
      });

  @override
  void sleep([List<String>? ids]) => _apply(ids, (d) => d.screenOn = false);

  @override
  void updateVehicle() {}
}
