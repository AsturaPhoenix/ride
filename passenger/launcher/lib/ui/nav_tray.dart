import 'dart:async';

import 'package:defer_pointer/defer_pointer.dart';
import 'package:device_apps/device_apps.dart';
import 'package:flutter/material.dart';
import 'package:quiver/collection.dart';
import 'package:quiver/iterables.dart';

import 'parallelogram_border.dart';

/// Apps on this platform don't seem to populate ApplicationCategory, so we need
/// our own.
enum RideAppCategory {
  info,
  music(['com.spotify.music']),
  video(['com.netflix.mediaclient', 'com.amazon.youtube_apk']),
  internet(['com.amazon.cloud9']),
  other;

  static final Map<String, RideAppCategory> _appIndex = {
    for (final category in values)
      for (final packageName in category.apps) packageName: category,
  };

  static RideAppCategory categorizeApp(final String packageName) =>
      _appIndex[packageName] ?? other;

  final List<String> apps;
  const RideAppCategory([this.apps = const []]);
}

class NavTray extends StatefulWidget {
  static const double tileHeight = 64.0;

  final bool locked;

  const NavTray({super.key, this.locked = true});

  @override
  State<StatefulWidget> createState() => NavTrayState();
}

class NavPageRoute extends MaterialPageRoute {
  NavPageRoute({required super.builder});

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.fastOutSlowIn,
            reverseCurve: Curves.fastOutSlowIn.flipped,
          ),
        ),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset.zero,
            end: const Offset(-1, 0),
          ).animate(
            CurvedAnimation(
              parent: secondaryAnimation,
              curve: Curves.fastOutSlowIn,
              reverseCurve: Curves.fastOutSlowIn.flipped,
            ),
          ),
          child: child,
        ),
      );
}

class _App extends ChangeNotifier {
  final String name;
  final String packageName;
  final ImageProvider icon;

  bool isLaunching = false;

  _App({required this.name, required this.packageName, required this.icon});

  Widget buildIcon(BuildContext context) => ListenableBuilder(
        listenable: this,
        builder: (context, child) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          switchInCurve: const Interval(0.5, 1.0),
          // A switch-out interval of 0,.5 would be a pure delay, but keeping it
          // linear is an interesting visual.
          child: isLaunching
              ? const CircularProgressIndicator()
              : Image(key: UniqueKey(), image: icon),
          // Unclear why at least one of these children needs a key to force the
          // animation, since they're different types.
        ),
      );

  Future<bool> open() async {
    isLaunching = true;
    notifyListeners();

    final completer = Completer();
    // onHide may not happen immediately upon app launch, but onInactive happens
    // even before the app begins to show up.
    final listener = AppLifecycleListener(onHide: completer.complete);

    try {
      if (await DeviceApps.openApp(packageName)) {
        // If we hit the home key before the app launches, we won't be notified,
        // so set a timeout.
        await completer.future.timeout(const Duration(seconds: 5));
        return true;
      } else {
        return false;
      }
    } on TimeoutException {
      return false;
    } finally {
      listener.dispose();
      isLaunching = false;
      notifyListeners();
    }
  }
}

class NavTrayState extends State<NavTray> {
  final navigatorKey = GlobalKey<NavigatorState>();

  late Stream<Multimap<RideAppCategory, _App>> _apps;
  final _iconCache = <String, ImageProvider>{};

  @override
  void initState() {
    super.initState();

    _apps = () async* {
      Future<List<Application>> refresh({required bool needsIcons}) =>
          DeviceApps.getInstalledApplications(
            includeSystemApps: true,
            includeAppIcons: needsIcons,
            onlyAppsWithLaunchIntent: true,
          );

      yield await refresh(needsIcons: true);

      await for (final change in DeviceApps.listenToAppsChanges()) {
        if (const {
          ApplicationEventType.updated,
          ApplicationEventType.uninstalled,
          ApplicationEventType.disabled,
        }.contains(change.event)) {
          _iconCache.remove(change.packageName);
        }

        yield await refresh(
          needsIcons: const {
            ApplicationEventType.installed,
            ApplicationEventType.updated,
            ApplicationEventType.enabled,
          }.contains(change.event),
        );
      }
    }()
        .asyncMap(
      (apps) async {
        final preloads = <Future>[];
        final result = Multimap.fromIterable(
          apps,
          key: (app) =>
              RideAppCategory.categorizeApp((app as Application).packageName),
          value: (app) => _App(
            name: (app as Application).appName,
            packageName: app.packageName,
            icon: _iconCache[app.packageName] ??= () {
              final image = MemoryImage((app as ApplicationWithIcon).icon);
              preloads.add(precacheImage(image, context));
              return image;
            }(),
          ),
        );
        await Future.wait(preloads);
        return result;
      },
    );
  }

  Widget _createRootPage(
    BuildContext context,
    Multimap<RideAppCategory, _App> apps,
  ) =>
      GridView.custom(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 24,
          mainAxisSpacing: 24,
          mainAxisExtent: NavTray.tileHeight,
        ),
        padding: const EdgeInsets.all(64),
        childrenDelegate: SliverChildListDelegate.fixed([
          for (final category in {
            RideAppCategory.info: 'Info',
            RideAppCategory.music: 'Music',
            RideAppCategory.video: 'Video',
            RideAppCategory.internet: 'Internet',
            if (!widget.locked) RideAppCategory.other: 'Other',
          }.entries.map(
                (entry) => (
                  type: entry.key,
                  name: entry.value,
                  apps: [...apps[entry.key]]
                ),
              ))
            if (category.apps.isNotEmpty)
              Hero(
                tag: category,
                child: NavButton(
                  icons: [
                    for (final app in category.apps.take(4))
                      app.buildIcon(context),
                  ],
                  text: category.name,
                  onPressed: category.apps.length == 1
                      ? category.apps.single.open
                      : () => Navigator.of(context).push(
                            NavPageRoute(
                              builder: (context) =>
                                  _createCategoryPage(context, category),
                            ),
                          ),
                ),
              ),
        ]),
      );

  Widget _createCategoryPage(
    BuildContext context,
    ({RideAppCategory type, String name, List<_App> apps}) category,
  ) =>
      Stack(
        clipBehavior: Clip.none,
        children: [
          Theme(
            data: ThemeData.dark(),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisExtent: NavTray.tileHeight + 24,
              ),
              padding: const EdgeInsets.all(64),
              itemCount: category.apps.length,
              itemBuilder: (context, index) {
                final app = category.apps[index];
                return TextButton(
                  onPressed: app.open,
                  child: ListTile(
                    leading: AspectRatio(
                      aspectRatio: 1.0,
                      child: app.buildIcon(context),
                    ),
                    title: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(app.name),
                    ),
                    subtitle: category.type == RideAppCategory.other
                        ? Text(app.packageName, overflow: TextOverflow.ellipsis)
                        : null,
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: 64 - 32,
            right: 64 + 32 + 24,
            child: Row(
              children: [
                Expanded(
                  child: SizedOverflowBox(
                    size: const Size.fromHeight(0),
                    child: DeferPointer(
                      child: SizedBox(
                        height: NavTray.tileHeight,
                        child: Hero(
                          tag: category,
                          child: NavButton(
                            elevation: 2.0,
                            icons: const [Icon(Icons.arrow_back)],
                            text: category.name,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) => DeferredPointerHandler(
        child: FractionallySizedBox(
          heightFactor: .4,
          child: Material(
            elevation: 1.0,
            color: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
            child: StreamBuilder(
              stream: _apps,
              builder: (context, apps) => apps.hasData
                  ? NavigatorPopHandler(
                      onPop: () => navigatorKey.currentState!.maybePop(),
                      child: Navigator(
                        key: navigatorKey,
                        clipBehavior: Clip.none,
                        observers: [HeroController()],
                        onGenerateRoute: (settings) => NavPageRoute(
                          builder: (context) =>
                              _createRootPage(context, apps.data!),
                        ),
                      ),
                    )
                  : const LinearProgressIndicator(),
            ),
          ),
        ),
      );
}

class NavButton extends StatelessWidget {
  final double? elevation;
  final String text;
  final List<Widget> icons;
  final void Function()? onPressed;

  const NavButton({
    super.key,
    this.elevation,
    this.icons = const [],
    required this.text,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: elevation,
          shape: const ParallelogramBorder(skew: .4),
        ),
        child: ListTile(
          leading: AspectRatio(
            aspectRatio: 1.0,
            child: Column(
              key: ValueKey(icons),
              children: [
                for (final row in partition(icons, 2))
                  Flexible(
                    fit: FlexFit.tight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final icon in row)
                          Flexible(
                            fit: FlexFit.tight,
                            child: icon,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(text),
          ),
        ),
      );
}
