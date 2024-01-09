import 'package:flutter/material.dart';

class RideOverlay extends StatelessWidget {
  static void main() => runApp(const RideOverlay());

  const RideOverlay({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.transparent,
          bottomNavigationBar: BottomAppBar(
            child: Text('BOTTOM'),
          ),
        ),
      );
}
