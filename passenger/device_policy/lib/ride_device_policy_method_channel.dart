import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ride_device_policy_platform_interface.dart';

/// An implementation of [RideDevicePolicyPlatform] that uses method channels.
class MethodChannelRideDevicePolicy extends RideDevicePolicyPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('ride_device_policy');

  @override
  Future<bool> requestAdminIfNeeded([String? explanation]) async =>
      await methodChannel.invokeMethod('requestAdminIfNeeded', explanation)
          as bool;
  @override
  Future<void> setSystemSetting(String setting, String? value) =>
      methodChannel.invokeMethod('setSystemSetting', [setting, value]);
  @override
  Future<String?> getSystemSetting(String setting) =>
      methodChannel.invokeMethod<String>('getSystemSetting', setting);
  @override
  Future<void> home() => methodChannel.invokeMethod('home');
  @override
  Future<void> wakeUp() => methodChannel.invokeMethod('wakeUp');
  @override
  Future<void> lockNow() => methodChannel.invokeMethod('lockNow');
}
