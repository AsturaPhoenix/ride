import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:overlay_window/overlay_window.dart';

import '../core/config.dart' as core;
import '../core/fake_server.dart';
import '../core/server.dart' as core;
import '../core/tesla.dart' as tesla;
import 'assets.dart';
import 'devices.dart';
import 'server.dart';
import 'tesla.dart';

class Config extends StatefulWidget {
  const Config({super.key});

  @override
  State<StatefulWidget> createState() => ConfigState();
}

class ConfigState extends State<Config> {
  late final core.Config config;
  late final core.ServerManager serverManager;
  TextEditingController? portFieldController;
  tesla.Client? teslaClient;

  AppLifecycleListener? _appLifecycleListener;

  @override
  void initState() {
    super.initState();

    OverlayWindow.requestPermissions();

    () async {
      final [
        core.Config config as core.Config,
        serverManager as core.ServerManager
      ] = await Future.wait([
        core.Config.load(),
        if (kIsWeb)
          Future.value(FakeServerManager())
        else
          core.ServerManager.initialize(),
      ]);

      if (!mounted) return;

      setState(() {
        this.config = config;
        this.serverManager = serverManager;
        portFieldController =
            TextEditingController(text: config.serverPort.toString());
      });
      updateTeslaClient();

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
        updateTeslaClient();
      });

      _appLifecycleListener = AppLifecycleListener(
        onShow: () => serverManager.showOverlay(false),
        onHide: () => serverManager.showOverlay(true),
      )..onShow!();
    }();
  }

  @override
  void dispose() {
    _appLifecycleListener?.dispose();
    teslaClient?.close();
    portFieldController?.dispose();
    serverManager.dispose();
    super.dispose();
  }

  void updateTeslaClient() {
    if (config.teslaCredentials == null && teslaClient != null) {
      teslaClient?.close();
      setState(() => teslaClient = null);
    } else if (serverManager.lifecycleState ==
        core.ServerLifecycleState.started) {
      if (teslaClient?.remote is! core.ServiceTeslaRemote) {
        teslaClient?.close();
        setState(() => teslaClient = tesla.Client(core.ServiceTeslaRemote()));
      }
    } else if (teslaClient?.remote is! tesla.Oauth2ClientRemote) {
      teslaClient?.close();
      setState(() => teslaClient = tesla.Client.oauth2(config));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (portFieldController == null) {
      return const LinearProgressIndicator();
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (_) async {
        // This hack is required because the system would otherwise kill the
        // isolate before the message on the service method channel leaves the
        // station, so that even though we try to invoke the message, the
        // service never receives it.
        serverManager.showOverlay(true);
        await SystemNavigator.pop();
      },
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
              if (serverState != null) Devices(serverManager: serverManager),
              Expanded(
                child: Tesla(
                  client: teslaClient,
                  vehicleId: config.vehicleId,
                  error: serverState?.lastErrors.vehicle,
                  setCredentials: (value) {
                    setState(() => config.teslaCredentials = value?.toJson());
                    updateTeslaClient();
                    serverManager.updateVehicle();
                  },
                  setVehicle: (vehicleId) {
                    setState(() => config.vehicleId = vehicleId);
                    serverManager.updateVehicle();
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
