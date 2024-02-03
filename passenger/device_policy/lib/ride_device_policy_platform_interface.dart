import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'ride_device_policy_method_channel.dart';

abstract class RideDevicePolicyPlatform extends PlatformInterface {
  /// Constructs a RideDevicePolicyPlatform.
  RideDevicePolicyPlatform() : super(token: _token);

  static final Object _token = Object();

  static RideDevicePolicyPlatform _instance = MethodChannelRideDevicePolicy();

  /// The default instance of [RideDevicePolicyPlatform] to use.
  ///
  /// Defaults to [MethodChannelRideDevicePolicy].
  static RideDevicePolicyPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [RideDevicePolicyPlatform] when
  /// they register themselves.
  static set instance(RideDevicePolicyPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Stream<String> get windowEvents;

  Future<bool> requestAdminIfNeeded([String? explanation]);
  Future<bool> requestAccessibilityIfNeeded();
  Future<void> setSystemSetting(String setting, String? value);
  Future<String?> getSystemSetting(String setting);
  Future<void> home();
  Future<void> wakeUp();
  Future<void> lockNow();
  Future<void> setVolume(double value);
}
