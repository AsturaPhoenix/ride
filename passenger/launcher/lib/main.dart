import 'package:flutter/material.dart';

import 'core/client.dart';
import 'core/config.dart';
import 'ui/nav_tray.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = await Config.load();

  runApp(RideLauncher(clientManager: ClientManager(config)..start()));
}

class RideLauncher extends StatelessWidget {
  final ClientManager clientManager;
  const RideLauncher({super.key, required this.clientManager});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'RIDE',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
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
        home: WillPopScope(
          onWillPop: () async => false,
          child: Scaffold(
            body: ListenableBuilder(
              listenable: clientManager,
              builder: (context, _) => Text(clientManager.status.toString()),
            ),
            bottomNavigationBar: const NavTray(),
          ),
        ),
      );
}
