import 'package:flutter/material.dart';

import '../core/server.dart';

class Devices extends StatelessWidget {
  final ServerManager serverManager;

  const Devices({super.key, required this.serverManager});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(
          left: 24.0,
          top: 16.0,
          right: 16.0,
          bottom: 16.0,
        ),
        child: Row(
          children: [
            IconButton.filledTonal(
              icon: const Icon(Icons.light_mode),
              tooltip: 'Wake all',
              onPressed: serverManager.wakeAll,
            ),
            const SizedBox(width: 8.0),
            IconButton.filled(
              icon: const Icon(Icons.dark_mode),
              tooltip: 'Sleep all',
              onPressed: serverManager.sleepAll,
            ),
          ],
        ),
      );
}
