import 'package:flutter/material.dart';

import 'core/client.dart';
import 'core/config.dart';
import 'ui/greetings.dart';
import 'ui/nav_tray.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = await Config.load();

  runApp(RideLauncher(clientManager: ClientManager(config)..start()));
}

class RideLauncher extends StatefulWidget {
  final ClientManager clientManager;
  const RideLauncher({super.key, required this.clientManager});

  @override
  State<RideLauncher> createState() => _RideLauncherState();
}

class _RideLauncherState extends State<RideLauncher> implements ClientListener {
  final greetingsController = GreetingsController();

  @override
  void initState() {
    super.initState();
    widget.clientManager.listener = this;
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
              backgroundColor: Colors.white,
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
            bottomNavigationBar: const NavTray(),
          ),
        ),
      );
}
