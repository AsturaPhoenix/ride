import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/client.dart';
import 'fake/device_apps.dart';
import 'ui/launcher.dart';
import 'ui/nav_tray.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // This translates into about 50 MiB of graphics memory, or 90 MiB total,
  // which is a lot friendlier than the default, where it can grow to 130/200+,
  // which puts observable pressure on other apps.
  imageCache.maximumSizeBytes = 20 << 20;

  final ClientManager? clientManager;
  final DeviceAppsImpl? deviceApps;
  final controller = RideLauncherController();

  if (kIsWeb) {
    clientManager = null;

    deviceApps = FakeDeviceApps()..apps = FakeDeviceApps.standardApps;

    bool keyHandler(KeyEvent event) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.home:
          controller.home();
          return true;
      }
      return false;
    }

    controller.onBind = () => HardwareKeyboard.instance.addHandler(keyHandler);
    controller.onUnbind =
        () => HardwareKeyboard.instance.removeHandler(keyHandler);
  } else {
    clientManager = await ClientManager.initialize()
      ..start();

    deviceApps = null;

    const intentsChannel = EventChannel('ride_launcher.intents');
    late StreamSubscription intentsSubscription;

    controller.onBind = () => intentsSubscription =
            intentsChannel.receiveBroadcastStream().listen((intent) {
          switch (intent) {
            case {
                'action': 'android.intent.action.MAIN',
                'categories': final List categories,
              }:
              if (categories.contains('android.intent.category.HOME')) {
                controller.home();
              }
              break;
          }
        });
    controller.onUnbind = () => intentsSubscription.cancel();
  }

  runApp(
    RideLauncher(
      clientManager: clientManager,
      deviceApps: deviceApps,
      controller: controller,
    ),
  );
}
