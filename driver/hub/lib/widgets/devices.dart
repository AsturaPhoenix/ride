import 'package:flutter/material.dart';

import '../core/server.dart';

// I think this should be equivalent to
// ColorFilter.mode(color, BlendMode.multiply), but for some reason it's not.
ColorFilter _colorFilterMultiply(Color color) => ColorFilter.matrix([
      //format: off
      color.red / 255, 0, 0, 0, 0,
      0, color.green / 255, 0, 0, 0,
      0, 0, color.blue / 255, 0, 0,
      0, 0, 0, color.alpha / 255, 0,
      //format: on
    ]);

class Devices extends StatelessWidget {
  static String abbreviatePackageName(String packageName) =>
      packageName.splitMapJoin('.', onNonMatch: (s) => s.isEmpty ? '' : s[0]);

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: SizedBox(
                width: 160.0,
                height: 160.0,
                child: GridView.count(
                  crossAxisCount: 2,
                  padding: const EdgeInsets.all(8.0),
                  mainAxisSpacing: 8.0,
                  crossAxisSpacing: 8.0,
                  children: [
                    if (serverManager.serverState != null)
                      for (final connection
                          in serverManager.serverState!.connections.values)
                        TweenAnimationBuilder(
                          tween: ColorTween(
                            // Although ColorTween treats null as transparent,
                            // TweenAnimationBuilder interprets it as meaning
                            // the animation should start at the end value.
                            begin: Colors.white.withOpacity(0.0),
                            end: connection.screenOn != false
                                ? Colors.white
                                : Colors.grey,
                          ),
                          duration: const Duration(milliseconds: 250),
                          builder: (context, value, child) => ColorFiltered(
                            colorFilter: _colorFilterMultiply(value!),
                            child: child,
                          ),
                          child: CircleAvatar(
                            backgroundColor: Colors.grey.shade300,
                            child: connection.foregroundPackage == null
                                ? null
                                : Text(
                                    abbreviatePackageName(
                                      connection.foregroundPackage!,
                                    ),
                                  ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            IconButtonTheme(
              data: IconButtonThemeData(
                style: IconButton.styleFrom(iconSize: 32.0),
              ),
              child: Row(
                children: [
                  IconButton.outlined(
                    icon: const Icon(Icons.light_mode),
                    tooltip: 'Wake',
                    onPressed: serverManager.wake,
                  ),
                  const SizedBox(width: 8.0),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.home),
                    tooltip: 'Home',
                    onPressed: serverManager.home,
                  ),
                  const SizedBox(width: 8.0),
                  IconButton.filled(
                    icon: const Icon(Icons.dark_mode),
                    tooltip: 'Sleep',
                    onPressed: serverManager.sleep,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
