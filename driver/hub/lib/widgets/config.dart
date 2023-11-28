import 'package:flutter/material.dart';

import '../core/config.dart' as core;
import '../core/server.dart' as core;
import 'assets.dart';
import 'server.dart';

class Config extends StatefulWidget {
  const Config({super.key});

  @override
  State<StatefulWidget> createState() => ConfigState();
}

class ConfigState extends State<Config> {
  late final core.Config config;
  late final core.ServerManager serverManager;
  TextEditingController? portFieldController;

  @override
  void initState() {
    super.initState();

    () async {
      final [config, serverManager] = await Future.wait([
        core.Config.load(),
        core.ServerManager.initialize(),
      ]);

      config as core.Config;
      serverManager as core.ServerManager;

      if (mounted) {
        setState(() {
          this.config = config;
          this.serverManager = serverManager;
          portFieldController =
              TextEditingController(text: config.serverPort.toString());
        });

        serverManager.addListener(() {
          final serverState = serverManager.serverState;
          if (serverState != null) {
            portFieldController!.text = serverState.port.toString();

            // Since we're using the text field to display the actual port
            // number, go ahead and bake it into the config for consistency.
            if (config.serverPort == 0) {
              config.serverPort = serverState.port;
            }
          }
        });
      }
    }();
  }

  @override
  void dispose() {
    portFieldController?.dispose();
    serverManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (portFieldController == null) {
      return const LinearProgressIndicator();
    }

    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: ListenableBuilder(
        listenable: serverManager,
        builder: (context, _) {
          final serverState = serverManager.serverState;
          final double assetsProgress;
          if (serverState == null) {
            assetsProgress = 1.0;
          } else {
            final hasAssets =
                serverState.connections.values.where((c) => c.hasAssets).length;
            final connectionCount = serverState.connections.length;
            if (hasAssets == 0 && connectionCount == 0) {
              assetsProgress = 1.0;
            } else {
              assetsProgress = hasAssets / connectionCount;
            }
          }

          return Column(
            children: [
              Assets(
                assets: config.assets,
                progress: assetsProgress,
                error: serverState?.lastErrors.assets,
                onPick: (assets) {
                  setState(() => config.assets = assets);
                  serverManager.pushAssets();
                  // There could be a delay between this call and when the
                  // status updates to reflect outstanding asset transfers and
                  // the spinner shows up.
                },
              ),
              Server(
                state: serverManager.lifecycleState,
                error:
                    serverManager.lastError ?? serverState?.lastErrors.general,
                portFieldController: portFieldController,
                connectionCount: serverState?.connections.length,
                start: serverManager.start,
                stop: serverManager.stop,
                setPort: serverManager.lifecycleState ==
                        core.ServerLifecycleState.stopped
                    ? (value) => setState(() => config.serverPort = value)
                    : null,
              ),
            ],
          );
        },
      ),
    );
  }
}
