import 'package:flutter/foundation.dart';

import '../core/client.dart';

class FakeClientManager extends ChangeNotifier implements ClientManager {
  @override
  ClientListener? listener;

  @override
  void setTemperature(double value) {
    vehicle?['temperature']['setting'] = value;
    notifyListeners();
  }

  @override
  void setVolume(double value) {
    vehicle?['volume']['setting'] = value;
    notifyListeners();
  }

  @override
  void showOverlays(bool show) {}

  @override
  Future<void> start() async {}

  @override
  ClientStatus get status => ClientStatus.disconnected;

  @override
  Future<void> stop() async {}

  @override
  Map? vehicle = {
    'temperature': {
      'setting': 25,
      'meta': {
        'min': 15,
        'max': 28,
      },
      'internal': 25,
      'external': 25,
    },
    'volume': {
      'setting': 5,
      'meta': {
        'step': 1 / 3,
        'max': 10 + 1 / 3,
      },
    },
  };
}
