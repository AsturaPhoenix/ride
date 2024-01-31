import 'package:flutter/foundation.dart';
import 'package:ride_shared/protocol.dart';

import '../core/client.dart';

class FakeClientManager extends ChangeNotifier implements ClientManager {
  @override
  ClientListener? listener;

  @override
  void setTemperature(double value) {
    vehicle.climate.setting.fromDownstream(value);
    notifyListeners();
  }

  @override
  void setVolume(double value) {
    vehicle.volume.setting.fromDownstream(value);
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
  final vehicle = VehicleState()
    ..fromJson(
      {
        'climate': {
          'setting': 25,
          'meta': {
            'min': 15,
            'max': 28,
          },
          'interior': 25,
          'exterior': 25,
        },
        'volume': {
          'setting': 5,
          'meta': {
            'step': 1 / 3,
            'max': 10 + 1 / 3,
          },
        },
        'drive': {
          'destination':
              'A very long destination name like P. Sherman, 42 Wallaby Way, Sydney',
          'minutesToArrival': 5.5,
          'milesToArrival': 1.6427,
        },
      },
      UpdateDirection.fromUpstream,
    );
}
