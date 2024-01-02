import 'package:flutter/services.dart';

import 'ride_device_policy_platform_interface.dart';

/// An implementation of [RideDevicePolicyPlatform] that uses method channels.
class MethodChannelRideDevicePolicy extends RideDevicePolicyPlatform {
  static const methodChannel = MethodChannel('ride_device_policy');
  static const windowEventChannel =
      EventChannel('ride_device_policy.windowEvents');

  @override
  late final Stream<String> windowEvents =
      windowEventChannel.receiveBroadcastStream().cast();

  @override
  Future<bool> requestAdminIfNeeded([String? explanation]) async =>
      await methodChannel.invokeMethod('requestAdminIfNeeded', explanation)
          as bool;

  @override
  Future<bool> requestAccessibilityIfNeeded() async =>
      await methodChannel.invokeMethod('requestAccessibilityIfNeeded') as bool;
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
