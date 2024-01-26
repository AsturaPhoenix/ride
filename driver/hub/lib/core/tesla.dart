import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:oauth2/oauth2.dart' as oauth2;

import 'config.dart';

const clientId = 'ownerapi';
final authEndpoint = Uri.parse('https://auth.tesla.com/oauth2/v3/authorize'),
    tokenEndpoint = Uri.parse('https://auth.tesla.com/oauth2/v3/token'),
    authRedirectUrl = 'https://auth.tesla.com/void/callback';
const authScopes = ['openid', 'email', 'offline_access', 'vehicle_device_data'];

abstract class ClientRemote {
  Future<Map<String, dynamic>> call(
    String endpoint,
    Map<String, dynamic> queryParameters,
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
            onCredentialsRefreshed: (credentials) =>
                config.teslaCredentials = credentials.toJson(),
          ),
        );

  @override
  Future<Map<String, dynamic>> call(
    String endpoint,
    Map<String, dynamic> queryParameters,
  ) async {
    final response = await client.get(
      baseUrl.resolve(endpoint).replace(queryParameters: queryParameters),
      headers: const {'Content-Type': 'application/json'},
    );
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
    String endpoint,
    Map<String, dynamic> queryParameters,
  ) async {
    final response = await remote.call(endpoint, queryParameters);

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
    final response = await _call('api/1/products', {'page': page?.toString()});

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

  Vehicle(
    this.client,
    this.id, {
    this.vin,
    this.displayName,
  });

  Vehicle.fromJson(this.client, Map<String, dynamic> json)
      : id = json['id'] as int,
        vin = json['vin'] as String,
        displayName = json['display_name'] as String;

  Future<void> syncState() async {
    final response = client._call('$baseEndpoint/vehicle_data', {
      'endpoints': 'climate_state;drive_state;vehicle_state',
    });
  }
}
