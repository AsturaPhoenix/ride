import 'package:flutter/material.dart';

void main() {
  runApp(const RideLauncher());
}

class RideLauncher extends StatelessWidget {
  const RideLauncher({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RIDE',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: WillPopScope(
        onWillPop: () async => false,
        child: const Scaffold(body: Text('home')),
      ),
    );
  }
}
