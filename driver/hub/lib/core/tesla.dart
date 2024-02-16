import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:ride_shared/protocol.dart';

import 'config.dart';

const clientId = 'ownerapi';
final authEndpoint = Uri.parse('https://auth.tesla.com/oauth2/v3/authorize'),
    tokenEndpoint = Uri.parse('https://auth.tesla.com/oauth2/v3/token'),
    authRedirectUrl = 'https://auth.tesla.com/void/callback';
const authScopes = [
  'openid',
  'email',
  'offline_access',
  'vehicle_device_data',
  'vehicle_cmds',
];

const throttlePeriod = Duration(seconds: 2);

abstract class ClientRemote {
  Future<Map<String, dynamic>> call(
    String method,
    String endpoint,
    Map<String, dynamic> args,
  );

  void close();
}

class Oauth2ClientRemote implements ClientRemote {
  static final baseUrl = Uri.parse('https://owner-api.teslamotors.com');

  final oauth2.Client client;
  Oauth2ClientRemote(this.client);
  Oauth2ClientRemote.fromConfig(Config config)
      : this(
          oauth2.Client(
            oauth2.Credentials.fromJson(config.teslaCredentials!),
            identifier: clientId,
            onCredentialsRefreshed: (credentials) =>
                config.teslaCredentials = credentials.toJson(),
          ),
        );

  @override
  Future<Map<String, dynamic>> call(
    String method,
    String endpoint,
    Map<String, dynamic> args,
  ) async {
    Uri url = baseUrl.resolve(endpoint);
    if (method == 'GET') {
      url = url.replace(queryParameters: args);
    }

    final request = http.Request(method, url)
      ..headers['Content-Type'] = 'application/json';
    if (method == 'POST') {
      request.body = jsonEncode(args);
    }

    final response = await http.Response.fromStream(await client.send(request));

    if (response.statusCode != HttpStatus.ok) throw response.statusCode;
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  void close() => client.close();
}

class Client {
  final ClientRemote remote;

  Client(this.remote);
  Client.oauth2(Config config) : this(Oauth2ClientRemote.fromConfig(config));

  void close() => remote.close();

  Future<Map<String, dynamic>> _call(
    String method,
    String endpoint,
    Map<String, dynamic> args,
  ) async {
    final response = await remote.call(method, endpoint, args);

    if (response.containsKey('error') ||
        response.containsKey('error_description') ||
        response.containsKey('messages')) {
      throw response;
    }

    return response;
  }

  Future<(List<Vehicle> vehicles, int count)> vehicles({
    int? page,
    int? perPage,
  }) async {
    final response =
        await _call('GET', 'api/1/products', {'page': page?.toString()});

    return (
      [
        for (final vehicle in response['response'] as List)
          Vehicle.fromJson(this, vehicle as Map<String, dynamic>),
      ],
      response['count'] as int
    );
  }
}

enum VehicleTopic {
  climate('climate_state'),
  volume('vehicle_state'),
  drive('drive_state');

  final String source;
  const VehicleTopic(this.source);
}

class Vehicle {
  final Client client;

  late final baseEndpoint = 'api/1/vehicles/$id';

  final int id;
  String? vin;
  String? displayName;

  VehicleState state;

  final _throttle = (
    climate: Throttle(throttlePeriod),
    volume: Throttle(throttlePeriod),
  );

  Vehicle(this.client, this.id, [Duration updateShadow = Duration.zero])
      : state = VehicleState(updateShadow);

  void _set(Map<String, dynamic> json, [DateTime? now]) {
    now ??= DateTime.now();

    vin = json['vin'] as String?;
    displayName = json['display_name'] as String?;

    if (json case {'climate_state': final Map climateState}) {
      final driverTempSetting =
          (climateState['driver_temp_setting'] as num?)?.toDouble();
      final passengerTempSetting =
          (climateState['passenger_temp_setting'] as num?)?.toDouble();
      final tempSetting =
          driverTempSetting != null && passengerTempSetting != null
              ? (driverTempSetting + passengerTempSetting) / 2
              : driverTempSetting ?? passengerTempSetting;

      state.climate
        ..setting.fromUpstream(tempSetting, now)
        ..meta = (
          min: (climateState['min_avail_temp'] as num?)?.toDouble(),
          max: (climateState['max_avail_temp'] as num?)?.toDouble(),
        )
        ..interior = (climateState['inside_temp'] as num?)?.toDouble()
        ..exterior = (climateState['outside_temp'] as num?)?.toDouble();
    }

    if (json case {'vehicle_state': {'media_info': final Map mediaInfo}}) {
      state.volume
        ..setting
            .fromUpstream((mediaInfo['audio_volume'] as num?)?.toDouble(), now)
        ..meta = (
          max: (mediaInfo['audio_volume_max'] as num?)?.toDouble(),
          step: (mediaInfo['audio_volume_increment'] as num?)?.toDouble(),
        );
    }

    if (json case {'drive_state': final Map driveState}) {
      state.drive
        ..destination = driveState['active_route_destination'] as String?
        ..milesToArrival =
            (driveState['active_route_miles_to_arrival'] as num?)?.toDouble()
        ..minutesToArrival =
            (driveState['active_route_minutes_to_arrival'] as num?)?.toDouble()
        ..speed = (driveState['speed'] as num?)?.toDouble();
    }
  }

  Vehicle.fromJson(
    this.client,
    Map<String, dynamic> json, [
    Duration updateShadow = Duration.zero,
  ])  : id = json['id'] as int,
        state = VehicleState(updateShadow) {
    _set(json);
  }

  Future<void> syncState([Set<VehicleTopic>? topics]) async {
    final {'response': Map<String, dynamic> response} =
        await client._call('GET', '$baseEndpoint/vehicle_data', {
      'endpoints':
          (topics ?? {...VehicleTopic.values}).map((t) => t.source).join(';'),
    });

    _set(response);
  }

  static void _handlePostResponse(Map<String, dynamic> response) {
    if (response
        case {'response': {'result': false, 'reason': final String reason}}) {
      throw reason;
    }
  }

  Future<void> setClimate(double value, [DateTime? now]) async {
    state.climate.setting.fromDownstream(value, now);
    await _throttle.climate.add(
      () async => _handlePostResponse(
        await client._call('POST', '$baseEndpoint/command/set_temps', {
          'driver_temp': value,
          'passenger_temp': value,
        }),
      ),
    );
  }

  Future<void> setVolume(double value, [DateTime? now]) async {
    state.volume.setting.fromDownstream(value, now);
    await _throttle.volume.add(
      () async => _handlePostResponse(
        await client._call('POST', '$baseEndpoint/command/adjust_volume', {
          'volume': value,
        }),
      ),
    );
  }
}

class Throttle {
  final Duration period;
  Throttle(this.period);

  bool _busy = false;
  ({Future<void> Function() call, Completer<void> completer})? _next;

  void _execute(Future<void> Function() call, Completer<void> completer) {
    () async {
      try {
        final result = call();
        completer.complete(result);
        await Future.wait([result, Future.delayed(period)]);
      } on Object {
        // continue
      }
      final next = _next;
      if (next != null) {
        _next = null;
        _execute(next.call, next.completer);
      } else {
        _busy = false;
      }
    }();
  }

  Future<void> add(Future<void> Function() call) {
    final completer = Completer<void>();
    if (!_busy) {
      _busy = true;
      _execute(call, completer);
    } else {
      _next?.completer.complete();
      _next = (call: call, completer: completer);
    }
    return completer.future;
  }
}
