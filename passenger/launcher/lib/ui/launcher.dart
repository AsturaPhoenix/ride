import 'package:app_widget_host/app_widget_host.dart';
import 'package:flutter/material.dart';
import 'package:ride_device_policy/ride_device_policy.dart';

import '../core/client.dart';
import 'greetings.dart';
import 'nav_tray.dart';
import 'persistent_app_widget.dart';

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
    secondaryContainer: Colors.grey.shade500,
    primary: Colors.grey.shade100,
    onPrimary: Colors.black,
    secondary: Colors.grey.shade400,
  );
  static final theme = ThemeData(
    colorScheme: RideLauncher.colorScheme,
    useMaterial3: true,
    canvasColor: RideLauncher.colorScheme.primaryContainer,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: RideLauncher.colorScheme.primary,
        foregroundColor: RideLauncher.colorScheme.onPrimary,
        textStyle: const TextStyle(fontSize: 22),
      ),
    ),
    floatingActionButtonTheme:
        FloatingActionButtonThemeData(backgroundColor: colorScheme.secondary),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: Color(0xff006874)),
    bottomAppBarTheme: BottomAppBarTheme(
      color: RideLauncher.colorScheme.secondaryContainer,
    ),
  );
  static final darkTheme = theme.copyWith(
    shadowColor: Colors.grey.shade100,
    floatingActionButtonTheme: theme.floatingActionButtonTheme.copyWith(
      backgroundColor:
          theme.floatingActionButtonTheme.backgroundColor.darken(.3),
      foregroundColor: Colors.grey.shade100,
    ),
    bottomAppBarTheme: theme.bottomAppBarTheme
        .copyWith(color: RideLauncher.colorScheme.primary.darken(.3)),
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
            bottomNavigationBar: const BottomAppBar(
              height: RideLauncher.bottomAppBarHeight,
              shape: CircularNotchedRectangle(),
              child: Row(
                children: [
                  Spacer(),
                  SizedBox(width: 96.0 + 2 * 16.0),
                  Expanded(
                    child: PersistentAppWidget(
                      borderRadius: BorderRadius.all(Radius.circular(6.0)),
                      provider: ComponentName(
                        'com.spotify.music',
                        'com.spotify.widget.widget.SpotifyWidget',
                      ),
                    ),
                  ),
                ],
              ),
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
