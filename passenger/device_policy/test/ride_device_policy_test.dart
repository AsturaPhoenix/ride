import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:ride_device_policy/ride_device_policy.dart';
import 'package:ride_device_policy/ride_device_policy_method_channel.dart';
import 'package:ride_device_policy/ride_device_policy_platform_interface.dart';

class FakeRideDevicePolicyPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements RideDevicePolicyPlatform {
  final data = {
    SystemSetting.screenBrightness: '255',
    SystemSetting.screenOffTimeout:
        const Duration(minutes: 5).inMilliseconds.toString(),
  };

  @override
  Future<void> setSystemSetting(String setting, String? value) async {
    if (value == null) {
      data.remove(setting);
    } else {
      data[setting] = value;
    }
  }

  @override
  Future<String?> getSystemSetting(String setting) async => data[setting];
}

void main() {
  final RideDevicePolicyPlatform initialPlatform =
      RideDevicePolicyPlatform.instance;

  test('$MethodChannelRideDevicePolicy is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelRideDevicePolicy>());
  });

  group('fake tests', () {
    setUp(() =>
        RideDevicePolicyPlatform.instance = FakeRideDevicePolicyPlatform());

    test('screen brightness', () async {
      await RideDevicePolicy.setScreenBrightness(128);
      expect(await RideDevicePolicy.getScreenBrightness(), 128);
    });

    test('screen off timeout', () async {
      await RideDevicePolicy.setScreenOffTimeout(const Duration(days: 1));
      expect(await RideDevicePolicy.getScreenOffTimeout(),
          const Duration(days: 1));
    });
  });
}
