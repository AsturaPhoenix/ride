import 'package:flutter/material.dart';

import 'widgets/config.dart';

void main() {
  runApp(const RideHub());
}

class RideHub extends StatelessWidget {
  static final theme = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
    useMaterial3: true,
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
    ),
  );

  const RideHub({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'RIDE',
        theme: theme,
        home: Scaffold(
          appBar: AppBar(title: const Text('RIDE Hub')),
          body: const Config(),
        ),
      );
}
