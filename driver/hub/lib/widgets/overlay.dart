import 'package:flutter/material.dart';
import 'package:overlay_window/overlay_window.dart';

import '../core/config.dart' as core;
import '../core/server.dart';
import '../main.dart';
import 'devices.dart';

class RideHubOverlay extends StatelessWidget {
  @pragma('vm:entry-point')
  static Future<void> main(OverlayWindow window) async {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: RideHub.theme,
        home: RideHubOverlay(
          config: await core.Config.load(),
          window: window,
          serverManager: await ServerManager.initialize(),
        ),
      ),
    );
  }

  final core.Config config;
  final OverlayWindow window;
  final ServerManager serverManager;
  const RideHubOverlay({
    super.key,
    required this.config,
    required this.window,
    required this.serverManager,
  });

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: 0.75,
        child: Devices(
          serverManager: serverManager,
          config: config,
          overlayWindow: window,
        ),
      );
}
