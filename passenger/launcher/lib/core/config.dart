import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:ride_shared/defaults.dart' as defaults;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class Config {
  static const assetsSubdirectory = 'assets',
      idKey = 'id',
      assetsVersionKey = 'assets version',
      portKey = 'boot';

  static Future<String> getAssetsPath() async => path.join(
        (await getApplicationCacheDirectory()).path,
        assetsSubdirectory,
      );

  final SharedPreferences _sharedPreferences;

  String get id {
    var id = _sharedPreferences.getString(idKey);
    if (id == null) {
      id = const Uuid().v4();
      _sharedPreferences.setString(idKey, id);
    }
    return id;
  }

  set id(String value) => _sharedPreferences.setString(idKey, value);

  String? get assetsVersion => _sharedPreferences.getString(assetsVersionKey);

  set assetsVersion(String? value) {
    _sharedPreferences.setString(assetsVersionKey, value!);
  }

  int get serverPort =>
      _sharedPreferences.getInt(portKey) ?? defaults.serverPort;
  set serverPort(int value) => _sharedPreferences.setInt(portKey, value);

  const Config(this._sharedPreferences);
  static Future<Config> load() async =>
      Config(await SharedPreferences.getInstance());
}
