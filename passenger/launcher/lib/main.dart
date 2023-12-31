import 'package:flutter/material.dart';
import 'package:ride_device_policy/ride_device_policy.dart';

import 'core/client.dart';
import 'ui/greetings.dart';
import 'ui/nav_tray.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // This translates into about 50 MiB of graphics memory, or 90 MiB total,
  // which is a lot friendlier than the default, where it can grow to 130/200+,
  // which puts observable pressure on other apps.
  imageCache.maximumSizeBytes = 20 << 20;

  runApp(
    RideLauncher(
      clientManager: await ClientManager.initialize()
        ..start(),
    ),
  );
}

class RideLauncher extends StatefulWidget {
  final ClientManager clientManager;
  RideLauncher({super.key, ClientManager? clientManager})
      : clientManager = clientManager ?? ClientManager();

  @override
  State<RideLauncher> createState() => _RideLauncherState();
}

class _RideLauncherState extends State<RideLauncher> implements ClientListener {
  final greetingsController = GreetingsController();

  @override
  void initState() {
    super.initState();
    widget.clientManager.listener = this;

    () async {
      await RideDevicePolicy.requestAdminIfNeeded();
      await RideDevicePolicy.requestAccessibilityIfNeeded();
    }();
  }

  @override
  void didUpdateWidget(covariant RideLauncher oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.clientManager.listener = null;
    widget.clientManager.listener = this;
  }

  @override
  void dispose() {
    widget.clientManager.listener = null;
    super.dispose();
  }

  @override
  void assetsChanged() {
    greetingsController.reload();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'RIDE',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.white,
            background: Colors.grey.shade800,
          ),
          useMaterial3: true,
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade100,
              foregroundColor: Colors.black,
              textStyle: const TextStyle(fontSize: 22),
            ),
          ),
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            backgroundColor: Colors.grey.shade700,
          ),
        ),
        home: PopScope(
          canPop: false,
          child: Scaffold(
            body: Greetings(controller: greetingsController),
            bottomNavigationBar: ListenableBuilder(
              listenable: widget.clientManager,
              builder: (context, _) => NavTray(
                locked: widget.clientManager.status == ClientStatus.connected,
              ),
            ),
          ),
        ),
      );
}
