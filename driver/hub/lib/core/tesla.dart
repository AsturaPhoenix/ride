import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:oauth2/oauth2.dart' as oauth2;

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

class Vehicle {
  final Client client;

  late final baseEndpoint = 'api/1/vehicles/$id';

  final int id;
  String? vin;
  String? displayName;

  double? tempSetting, insideTemp, outsideTemp, minAvailTemp, maxAvailTemp;

  String? activeRouteDestination;
  double? activeRouteMilesToArrival;
  double? activeRouteMinutesToArrival;

  double? audioVolume, audioVolumeIncrement, audioVolumeMax;

  Vehicle(this.client, this.id);

  void _set(Map<String, dynamic> json) {
    vin = json['vin'] as String?;
    displayName = json['display_name'] as String?;

    final climateState = json['climate_state'];

    final driverTempSetting =
        (climateState?['driver_temp_setting'] as num?)?.toDouble();
    final passengerTempSetting =
        (climateState?['passenger_temp_setting'] as num?)?.toDouble();
    tempSetting = driverTempSetting != null && passengerTempSetting != null
        ? (driverTempSetting + passengerTempSetting) / 2
        : driverTempSetting ?? passengerTempSetting;
    insideTemp = (climateState?['inside_temp'] as num?)?.toDouble();
    outsideTemp = (climateState?['outside_temp'] as num?)?.toDouble();
    minAvailTemp = (climateState?['min_avail_temp'] as num?)?.toDouble();
    maxAvailTemp = (climateState?['max_avail_temp'] as num?)?.toDouble();

    final driveState = json['drive_state'];
    activeRouteDestination = driveState?['active_route_destination'] as String?;
    activeRouteMilesToArrival =
        (driveState?['active_route_miles_to_arrival'] as num?)?.toDouble();
    activeRouteMinutesToArrival =
        (driveState?['active_route_minutes_to_arrival'] as num?)?.toDouble();

    final mediaInfo = json['vehicle_state']?['media_info'];

    audioVolume = (mediaInfo?['audio_volume'] as num?)?.toDouble();
    audioVolumeIncrement =
        (mediaInfo?['audio_volume_increment'] as num?)?.toDouble();
    audioVolumeMax = (mediaInfo?['audio_volume_max'] as num?)?.toDouble();
  }

  Vehicle.fromJson(this.client, Map<String, dynamic> json)
      : id = json['id'] as int {
    _set(json);
  }

  Future<void> syncState() async {
    final {'response': response as Map<String, dynamic>} =
        await client._call('GET', '$baseEndpoint/vehicle_data', {
      'endpoints': 'climate_state;drive_state;vehicle_state',
    });

    _set(response);
  }

  Future<void> setTemperature(double value) =>
      client._call('POST', '$baseEndpoint/command/set_temps', {
        'driver_temp': value,
        'passenger_temp': value,
      });

  Future<void> setVolume(double value) =>
      client._call('POST', '$baseEndpoint/command/adjust_volume', {
        'volume': value,
      });
}
