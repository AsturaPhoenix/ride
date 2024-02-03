import 'dart:async';

import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:ride_device_policy/ride_device_policy.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

import '../core/client.dart';
import 'bottom_bar.dart';
import 'greetings.dart';
import 'nav_tray.dart';

extension on Color? {
  Color? darken(double brightness) =>
      Color.lerp(Colors.black, this, brightness);
}

class RideLauncherController {
  _RideLauncherState? _state;

  void Function()? onBind, onUnbind;

  void home() => _state!.home();
}

class RideLauncher extends StatefulWidget {
  static const nightShadeFadeDuration = Duration(milliseconds: 250);
  static const bottomAppBarHeight = 80.0;
  static final colorScheme = ColorScheme.fromSeed(
    seedColor: Colors.white,
    background: Colors.grey.shade800,
    primaryContainer: Colors.grey.shade700,
    onPrimaryContainer: Colors.grey.shade100,
    secondaryContainer: Colors.grey.shade400,
    primary: Colors.grey.shade100,
    onPrimary: Colors.black,
    secondary: Colors.grey.shade400,
    onSecondary: Colors.black,
  );
  static final theme = ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    canvasColor: colorScheme.primaryContainer,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        textStyle: const TextStyle(fontSize: 22),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.secondary,
      foregroundColor: colorScheme.onSecondary,
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: Color(0xff006874)),
    bottomAppBarTheme: BottomAppBarTheme(
      color: colorScheme.secondaryContainer,
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
    ),
    cardTheme: CardTheme(color: Colors.grey.shade600),
  );
  static final darkTheme = theme.copyWith(
    colorScheme: theme.colorScheme.copyWith(
      onSurface: Colors.grey.shade300,
      onPrimaryContainer: Colors.grey.shade300,
    ),
    brightness: Brightness.dark,
    textTheme: TextTheme.lerp(
      Typography.blackMountainView,
      Typography.whiteMountainView,
      .9,
    ),
    shadowColor: Colors.grey.shade100,
    floatingActionButtonTheme: theme.floatingActionButtonTheme.copyWith(
      backgroundColor:
          theme.floatingActionButtonTheme.backgroundColor.darken(.3),
      foregroundColor: Colors.grey.shade100,
    ),
    bottomAppBarTheme:
        theme.bottomAppBarTheme.copyWith(color: colorScheme.primary.darken(.3)),
    iconTheme: theme.iconTheme.copyWith(color: Colors.grey.shade300),
    cardTheme:
        theme.cardTheme.copyWith(color: theme.cardTheme.color.darken(.3)),
  );

  final ClientManager clientManager;
  final DeviceAppsImpl? deviceApps;
  final RideLauncherController? controller;
  RideLauncher({
    super.key,
    ClientManager? clientManager,
    this.deviceApps,
    this.controller,
  }) : clientManager = clientManager ?? ClientManager();

  @override
  State<RideLauncher> createState() => _RideLauncherState();
}

class _RideLauncherState extends State<RideLauncher> implements ClientListener {
  final greetingsController = GreetingsController();
  final navTrayController = NavTrayController();

  bool softSleep = false;

  AppLifecycleListener? _appLifecycleListener;
  Future<bool>? _spotifyRemoteConnect;
  CancelableOperation<void>? _spotifyKeepAlive;

  Future<bool> _ensureSpotifyConnected() async =>
      (await _spotifyRemoteConnect ?? false) ||
      // This may consistently fail to show the auth UI on our target device,
      // but periodically retrying seems to keep Spotify alive anyway. You may
      // need to auth on a different device.
      await (_spotifyRemoteConnect = SpotifySdk.connectToSpotifyRemote(
        clientId: 'f1e6c611b2b342b18aba74266c39ba3c',
        redirectUrl: 'http://localhost:80',
      ).catchError((e) async {
        try {
          // If we don't try to disconnect on some connection failures, future
          // attempts may fail fast.
          await SpotifySdk.disconnect();
        } on Object {
          // ignore
        }
        return false;
      }));

  CancelableOperation<void> _keepSpotifyAlive() {
    StreamSubscription? subscription;
    final completer =
        CancelableCompleter(onCancel: () => subscription?.cancel());

    () async {
      while (!await _ensureSpotifyConnected() && !completer.isCanceled) {
        await Future.delayed(const Duration(minutes: 1));
      }

      if (!completer.isCanceled) {
        // Whether or not this actually keeps Spotify alive has yet to be
        // exercised.
        subscription = SpotifySdk.subscribePlayerState().listen((_) {});
      }
    }();

    return completer.operation;
  }

  @override
  void initState() {
    super.initState();
    widget.clientManager.listener = this;
    assert(widget.controller?._state == null);
    widget.controller
      ?.._state = this
      ..onBind?.call();

    () async {
      await RideDevicePolicy.requestAdminIfNeeded();
      await RideDevicePolicy.requestAccessibilityIfNeeded();

      if (!mounted) return;

      // The Spotify widget doesn't actually keep the service alive, so we need
      // to do it with a remote connection.
      _appLifecycleListener = AppLifecycleListener(
        onShow: () {
          widget.clientManager.showOverlays(false);
          _spotifyKeepAlive = _keepSpotifyAlive();
        },
        onHide: () {
          widget.clientManager.showOverlays(true);
          _spotifyKeepAlive?.cancel();
          _spotifyKeepAlive = null;
        },
      )..onShow!();
    }();
  }

  @override
  void didUpdateWidget(covariant RideLauncher oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.clientManager.listener = null;
    widget.clientManager.listener = this;

    if (widget.controller != oldWidget.controller) {
      oldWidget.controller
        ?.._state = null
        ..onUnbind?.call();
      assert(widget.controller?._state == null);
      widget.controller
        ?.._state = this
        ..onBind?.call();
    }
  }

  @override
  void dispose() {
    _appLifecycleListener?.dispose();
    _spotifyKeepAlive?.cancel();
    () async {
      if (await _spotifyRemoteConnect ?? false) {
        await SpotifySdk.disconnect();
      }
    }();

    widget.controller
      ?.._state = null
      ..onUnbind?.call();
    widget.clientManager.listener = null;
    super.dispose();
  }

  @override
  void assetsChanged() {
    greetingsController.reload();
  }

  void home() {
    setState(() => softSleep = false);
    navTrayController.home();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'RIDE',
        theme: RideLauncher.theme,
        darkTheme: RideLauncher.darkTheme,
        themeMode: softSleep ? ThemeMode.dark : ThemeMode.light,
        themeAnimationDuration: RideLauncher.nightShadeFadeDuration,
        home: PopScope(
          canPop: false,
          onPopInvoked: (_) => setState(() => softSleep = false),
          child: Scaffold(
            body: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: Greetings(controller: greetingsController),
                    ),
                    SizedBox(
                      height: NavTray.padding * 2 +
                          NavTray.tileHeight * 2 +
                          NavTray.spacing +
                          RideLauncher.bottomAppBarHeight,
                      child: ListenableBuilder(
                        listenable: widget.clientManager,
                        builder: (context, _) => NavTray(
                          controller: navTrayController,
                          deviceApps: widget.deviceApps,
                          locked: widget.clientManager.status ==
                              ClientStatus.connected,
                          bottomGutter: RideLauncher.bottomAppBarHeight,
                          wantPops: !softSleep,
                        ),
                      ),
                    ),
                  ],
                ),
                IgnorePointer(
                  ignoring: !softSleep,
                  child: AnimatedOpacity(
                    duration: RideLauncher.nightShadeFadeDuration,
                    opacity: softSleep ? 1.0 : 0.0,
                    child: const ColoredBox(
                      key: ValueKey('nightshade'),
                      color: Colors.black,
                      child: SizedBox.expand(),
                    ),
                  ),
                ),
              ],
            ),
            extendBody: true,
            bottomNavigationBar: BottomAppBar(
              height: RideLauncher.bottomAppBarHeight,
              shape: const CircularNotchedRectangle(),
              child: BottomBarControls(clientManager: widget.clientManager),
            ),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerDocked,
            floatingActionButton: FloatingActionButton.large(
              shape: const CircleBorder(),
              onPressed: () => setState(() => softSleep = !softSleep),
              child: const Icon(Icons.power_settings_new),
            ),
          ),
        ),
      );
}
