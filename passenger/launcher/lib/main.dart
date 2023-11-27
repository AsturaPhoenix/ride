import 'package:flutter/material.dart';

import 'nav_tray.dart';

void main() {
  runApp(const RideLauncher());
}

class RideLauncher extends StatelessWidget {
  const RideLauncher({super.key});

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
          child: const Scaffold(
            body: Text('home'),
            bottomNavigationBar: NavTray(),
          ),
        ),
      );
}
