import 'package:flutter/material.dart';
import 'package:ride_device_policy/ride_device_policy.dart';

import '../core/client.dart';
import 'greetings.dart';
import 'nav_tray.dart';

extension on Color? {
  Color? darken(double brightness) =>
      Color.lerp(Colors.black, this, brightness);
}

class RideLauncher extends StatefulWidget {
  static const nightShadeFadeDuration = Duration(milliseconds: 300);
  static const bottomAppBarHeight = 80.0;
  static final colorScheme = ColorScheme.fromSeed(
    seedColor: Colors.white,
    background: Colors.grey.shade800,
    primaryContainer: Colors.grey.shade700,
    primary: Colors.grey.shade500,
    secondary: Colors.grey.shade400,
    tertiary: Colors.grey.shade100,
    onTertiary: Colors.black,
  );
  static final theme = ThemeData(
    colorScheme: RideLauncher.colorScheme,
    useMaterial3: true,
    canvasColor: RideLauncher.colorScheme.primaryContainer,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: RideLauncher.colorScheme.tertiary,
        foregroundColor: RideLauncher.colorScheme.onTertiary,
        textStyle: const TextStyle(fontSize: 22),
      ),
    ),
    floatingActionButtonTheme:
        FloatingActionButtonThemeData(backgroundColor: colorScheme.secondary),
    bottomAppBarTheme: BottomAppBarTheme(
      color: RideLauncher.colorScheme.primary,
    ),
  );
  static final darkTheme = theme.copyWith(
    shadowColor: Colors.white,
    floatingActionButtonTheme: theme.floatingActionButtonTheme.copyWith(
      backgroundColor:
          theme.floatingActionButtonTheme.backgroundColor.darken(.5),
      foregroundColor: Colors.cyanAccent,
    ),
    bottomAppBarTheme: theme.bottomAppBarTheme
        .copyWith(color: RideLauncher.colorScheme.primary.darken(.5)),
  );

  final ClientManager clientManager;
  RideLauncher({super.key, ClientManager? clientManager})
      : clientManager = clientManager ?? ClientManager();

  @override
  State<RideLauncher> createState() => _RideLauncherState();
}

class _RideLauncherState extends State<RideLauncher> implements ClientListener {
  final greetingsController = GreetingsController();

  bool softSleep = false;

  @override
  void initState() {
    super.initState();
    widget.clientManager.listener = this;

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
  }

  @override
  void dispose() {
    widget.clientManager.listener = null;
    super.dispose();
  }

  @override
  void assetsChanged() {
    greetingsController.reload();
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
          onPopInvoked:
              // We need to avoid the no-op setState if the NavTray is handling
              // the pop, or we could end up messing with hero animations,
              // making category buttons disappear.
              //
              // This may be a Flutter bug.
              softSleep ? (_) => setState(() => softSleep = false) : null,
          child: Scaffold(
            body: AnimatedSwitcher(
              duration: RideLauncher.nightShadeFadeDuration,
              child: Stack(
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
            ),
            extendBody: true,
            bottomNavigationBar: const BottomAppBar(
              height: RideLauncher.bottomAppBarHeight,
              shape: CircularNotchedRectangle(),
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
