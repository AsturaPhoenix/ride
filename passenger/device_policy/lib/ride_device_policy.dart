import 'ride_device_policy_platform_interface.dart';

final class SystemSetting {
  /// https://developer.android.com/reference/android/provider/Settings.System#SCREEN_BRIGHTNESS
  static const screenBrightness = 'screen_brightness';

  /// https://developer.android.com/reference/android/provider/Settings.System#SCREEN_OFF_TIMEOUT
  static const screenOffTimeout = 'screen_off_timeout';
}

class RideDevicePolicy {
  static T? _mapNonNull<T>(String? value, T Function(String) map) =>
      value == null ? null : map(value);

  static Future<void> setScreenBrightness(int brightness) =>
      RideDevicePolicyPlatform.instance.setSystemSetting(
        SystemSetting.screenBrightness,
        brightness.toString(),
      );

  static Future<int?> getScreenBrightness() async => _mapNonNull(
      await RideDevicePolicyPlatform.instance
          .getSystemSetting(SystemSetting.screenBrightness),
      int.parse);

  static Future<void> setScreenOffTimeout(Duration timeout) =>
      RideDevicePolicyPlatform.instance.setSystemSetting(
        SystemSetting.screenOffTimeout,
        timeout.inMilliseconds.toString(),
      );

  static Future<Duration?> getScreenOffTimeout() async => _mapNonNull(
      await RideDevicePolicyPlatform.instance
          .getSystemSetting(SystemSetting.screenOffTimeout),
      (value) => Duration(milliseconds: int.parse(value)));
}
