import 'package:ride_shared/defaults.dart' as defaults;
import 'package:shared_preferences/shared_preferences.dart';

class Config {
  static const assetsKey = 'assets',
      assetsVersionKey = 'assets version',
      portKey = 'boot',
      teslaCredentialsKey = 'tesla.credentials',
      teslaVehicleKey = 'tesla.vehicle';

  final SharedPreferences _sharedPreferences;

  String? get assets => _sharedPreferences.getString(assetsKey);
  set assets(String? value) => _sharedPreferences.setString(assetsKey, value!);

  String? get assetsVersion => _sharedPreferences.getString(assetsVersionKey);
  set assetsVersion(String? value) =>
      _sharedPreferences.setString(assetsVersionKey, value!);

  int get serverPort =>
      _sharedPreferences.getInt(portKey) ?? defaults.serverPort;
  set serverPort(int value) => _sharedPreferences.setInt(portKey, value);

  String? get teslaCredentials =>
      _sharedPreferences.getString(teslaCredentialsKey);

  set teslaCredentials(String? value) {
    if (value == null) {
      _sharedPreferences.remove(teslaCredentialsKey);
    } else {
      _sharedPreferences.setString(teslaCredentialsKey, value);
    }
  }

  int? get vehicleId => _sharedPreferences.getInt(teslaVehicleKey);

  set vehicleId(int? value) {
    if (value == null) {
      _sharedPreferences.remove(teslaVehicleKey);
    } else {
      _sharedPreferences.setInt(teslaVehicleKey, value);
    }
  }

  const Config(this._sharedPreferences);
  static Future<Config> load() async =>
      Config(await SharedPreferences.getInstance());

  Future<void> reload() => _sharedPreferences.reload();
}
