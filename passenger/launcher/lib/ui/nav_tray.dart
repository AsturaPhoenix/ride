import 'dart:async';

import 'package:defer_pointer/defer_pointer.dart';
import 'package:device_apps/device_apps.dart';
import 'package:flutter/material.dart';
import 'package:quiver/collection.dart';
import 'package:quiver/iterables.dart';

import '../core/platform.dart' as platform;
import 'parallelogram_border.dart';

/// Apps on this platform don't seem to populate ApplicationCategory, so we need
/// our own.
enum RideAppCategory {
  info,
  music(['com.spotify.music']),
  video(['com.netflix.mediaclient', 'com.amazon.youtube_apk']),
  browser(['com.android.chrome']),
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

class DeviceAppsImpl {
  const DeviceAppsImpl();

  Stream<ApplicationEvent> listenToAppsChanges() =>
      DeviceApps.listenToAppsChanges();
  Future<List<Application>> getInstalledApplications({
    required bool includeAppIcons,
  }) =>
      DeviceApps.getInstalledApplications(
        includeSystemApps: true,
        includeAppIcons: includeAppIcons,
        onlyAppsWithLaunchIntent: true,
      );
}

class NavTrayController {
  NavTrayState? state;

  void home() => state!.home();
}

class NavTray extends StatefulWidget {
  static const double tileHeight = 64.0, padding = 64.0, spacing = 24.0;

  final NavTrayController? controller;
  final DeviceAppsImpl deviceApps;
  final bool locked;

  /// Extra padding at the bottom so that scrollable items clear the bottom app
  /// bar if drawing behind it.
  final double bottomGutter;

  /// Suppress pops if the parent is handling it.
  final bool wantPops;

  const NavTray({
    super.key,
    this.controller,
    DeviceAppsImpl? deviceApps,
    this.locked = true,
    this.bottomGutter = 0.0,
    this.wantPops = true,
  }) : deviceApps = deviceApps ?? const DeviceAppsImpl();

  @override
  State<StatefulWidget> createState() => NavTrayState();
}

class NavPageTransitions extends PageTransitionsTheme {
  const NavPageTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
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
          child: isLaunching ? const CircularProgressIndicator() : child,
        ),
        child: Image(
          // Unclear why at least one of these children needs a key to force the
          // animation, since they're different types.
          key: ValueKey(icon),
          image: icon,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
              wasSynchronouslyLoaded
                  ? child
                  : AnimatedOpacity(
                      opacity: frame == null ? 0 : 1,
                      duration: const Duration(milliseconds: 100),
                      child: child,
                    ),
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
  static const categoryDisplay = {
    RideAppCategory.info: 'Info',
    RideAppCategory.music: 'Music',
    RideAppCategory.video: 'Video',
    RideAppCategory.browser: 'Browser',
    RideAppCategory.other: 'Other',
  };

  final navigatorKey = GlobalKey<NavigatorState>();

  final _heroController = HeroController();
  late Stream<Multimap<RideAppCategory, _App>> _apps;
  final _iconCache = <String, ImageProvider>{};
  RideAppCategory? selectedCategory;

  void home() => setState(() => selectedCategory = null);

  @override
  void initState() {
    super.initState();
    widget.controller?.state = this;
    _apps = _listenToApps();
  }

  @override
  void didUpdateWidget(covariant NavTray oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      widget.controller?.state = this;
      oldWidget.controller?.state = null;
    }
    if (widget.deviceApps != oldWidget.deviceApps) {
      _apps = _listenToApps();
    }
  }

  @override
  void dispose() {
    widget.controller?.state = null;
    super.dispose();
  }

  Stream<Multimap<RideAppCategory, _App>> _listenToApps() async* {
    yield await _getCategorizedApps(needsIcons: true);

    await for (final change in widget.deviceApps.listenToAppsChanges()) {
      if (const {
        ApplicationEventType.updated,
        ApplicationEventType.uninstalled,
        ApplicationEventType.disabled,
      }.contains(change.event)) {
        _iconCache.remove(change.packageName);
      }

      yield await _getCategorizedApps(
        needsIcons: const {
          ApplicationEventType.installed,
          ApplicationEventType.updated,
          ApplicationEventType.enabled,
        }.contains(change.event),
      );
    }
  }

  Future<Multimap<RideAppCategory, _App>> _getCategorizedApps({
    required bool needsIcons,
  }) =>
      widget.deviceApps
          .getInstalledApplications(includeAppIcons: needsIcons)
          .then(
            (apps) => Multimap.fromIterable(
              apps,
              key: (app) => RideAppCategory.categorizeApp(
                (app as Application).packageName,
              ),
              value: (app) => _App(
                name: (app as Application).appName,
                packageName: app.packageName,
                icon: _iconCache[app.packageName] ??=
                    MemoryImage((app as ApplicationWithIcon).icon),
              ),
            ),
          );

  EdgeInsets get _scrollPadding => EdgeInsets.fromLTRB(
        NavTray.padding,
        NavTray.padding,
        NavTray.padding,
        NavTray.padding + widget.bottomGutter,
      );

  Widget _createRootPage(
    BuildContext context,
    Multimap<RideAppCategory, _App> apps,
  ) =>
      GridView.custom(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: NavTray.spacing,
          mainAxisSpacing: NavTray.spacing,
          mainAxisExtent: NavTray.tileHeight,
        ),
        padding: _scrollPadding,
        childrenDelegate: SliverChildListDelegate.fixed([
          for (final category in categoryDisplay.entries.map(
            (entry) => (
              type: entry.key,
              name: entry.value,
              apps: apps[entry.key],
            ),
          ))
            if ((category.type != RideAppCategory.other || !widget.locked) &&
                category.apps.isNotEmpty)
              Hero(
                tag: category.type,
                child: NavButton(
                  icons: [
                    for (final app in category.apps.take(4))
                      app.buildIcon(context),
                  ],
                  text: category.name,
                  onPressed: category.apps.skip(1).isEmpty
                      ? category.apps.single.open
                      : () => setState(() => selectedCategory = category.type),
                ),
              ),
        ]),
      );

  Widget _createCategoryPage(
    BuildContext context,
    RideAppCategory type,
    List<_App> apps, {
    List<Widget> extraChildren = const [],
  }) =>
      Stack(
        clipBehavior: Clip.none,
        children: [
          Theme(
            data: ThemeData.dark(),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisExtent: NavTray.tileHeight + NavTray.spacing,
              ),
              padding: _scrollPadding,
              itemCount: apps.length + extraChildren.length,
              itemBuilder: (context, index) {
                if (index < apps.length) {
                  final app = apps[index];
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
                      subtitle: type == RideAppCategory.other
                          ? Text(
                              app.packageName,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                    ),
                  );
                } else {
                  return extraChildren[index - apps.length];
                }
              },
            ),
          ),
          Positioned(
            left: NavTray.padding * 0.5,
            right: NavTray.padding * 1.5 + NavTray.spacing,
            child: Row(
              children: [
                Expanded(
                  child: SizedOverflowBox(
                    size: const Size.fromHeight(0),
                    child: DeferPointer(
                      child: SizedBox(
                        height: NavTray.tileHeight,
                        child: Hero(
                          tag: type,
                          child: NavButton(
                            elevation: 2.0,
                            icons: const [Icon(Icons.arrow_back)],
                            text: categoryDisplay[type]!,
                            onPressed: () => Navigator.pop(context),
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
        child: Material(
          elevation: 1.0,
          child: Theme(
            data: Theme.of(context)
                .copyWith(pageTransitionsTheme: const NavPageTransitions()),
            child: StreamBuilder(
              stream: _apps,
              builder: (context, apps) => apps.hasData
                  ? NavigatorPopHandler(
                      enabled: widget.wantPops,
                      onPop: widget.wantPops
                          ? () => navigatorKey.currentState!.maybePop()
                          : null,
                      child: Navigator(
                        key: navigatorKey,
                        clipBehavior: Clip.none,
                        observers: [_heroController],
                        pages: [
                          MaterialPage(
                            child: _createRootPage(context, apps.data!),
                          ),
                          if (selectedCategory != null)
                            MaterialPage(
                              child: Builder(
                                builder: (context) => _createCategoryPage(
                                  context,
                                  selectedCategory!,
                                  [...apps.data![selectedCategory]],
                                  extraChildren:
                                      selectedCategory == RideAppCategory.other
                                          ? const [ProvisionToggle()]
                                          : const [],
                                ),
                              ),
                            ),
                        ],
                        onPopPage: (route, _) {
                          if (route.didPop(null) && selectedCategory != null) {
                            setState(() => selectedCategory = null);
                          }
                          return false;
                        },
                      ),
                    )
                  : const UnconstrainedBox(
                      alignment: Alignment.topCenter,
                      constrainedAxis: Axis.horizontal,
                      child: LinearProgressIndicator(),
                    ),
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

/// It's very difficult to disable the lock screen and status bar on these
/// devices. One of the more surefire ways is by setting `device_provisioned` to
/// `'0'`, but that also disables developer options and eventually we lose ADB
/// access and need to factory reset.
class ProvisionToggle extends StatefulWidget {
  const ProvisionToggle({super.key});

  @override
  ProvisionToggleState createState() => ProvisionToggleState();
}

class ProvisionToggleState extends State<ProvisionToggle> {
  static Future<String> getProvisioned() => platform.run('su', const [
        '-c',
        'settings',
        'get',
        'global',
        'device_provisioned',
      ]);

  static Future<void> putProvisioned(String value) => platform.run('su', [
        '-c',
        'settings',
        'put',
        'global',
        'device_provisioned',
        value,
      ]);

  late Future<String> provisioned;

  @override
  void initState() {
    super.initState();

    provisioned = getProvisioned();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: provisioned,
        builder: (context, snapshot) {
          final provisioned = snapshot.data?.trim();

          return TextButton(
            onPressed: () => setState(() {
              this.provisioned = () async {
                if (provisioned == '1') {
                  await putProvisioned('0');
                  // We need to reboot to get the lock screen to vanish.
                  await platform.run('su', const ['-c', 'reboot']);
                } else {
                  await putProvisioned('1');
                }
                return getProvisioned();
              }();
            }),
            child: ListTile(
              leading: Padding(
                padding: const EdgeInsets.all(4.0),
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: snapshot.connectionState != ConnectionState.done
                          ? const CircularProgressIndicator()
                          : snapshot.hasData
                              ? Text(
                                  provisioned!,
                                  style: const TextStyle(color: Colors.black),
                                )
                              : Tooltip(
                                  message: snapshot.error?.toString(),
                                  child: const Icon(Icons.error),
                                ),
                    ),
                  ),
                ),
              ),
              title: const Text('Toggle provisioned'),
            ),
          );
        },
      );
}
