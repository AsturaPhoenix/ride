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
        'FR': (hasAssets: true),
        'RL': (hasAssets: true),
        'RR': (hasAssets: true),
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

  @override
  void wakeAll() {}

  @override
  void sleepAll() {}
}
