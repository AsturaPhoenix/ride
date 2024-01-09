import 'package:flutter/material.dart';

import 'core/client.dart';
import 'ui/launcher.dart';

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
