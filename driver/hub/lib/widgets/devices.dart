import 'dart:async';

import 'package:flutter/material.dart';
import 'package:overlay_window/overlay_window.dart';

import '../core/config.dart' as core;
import '../core/server.dart';
import '../main.dart';

class Devices extends StatefulWidget {
  static String abbreviatePackageName(String packageName) =>
      packageName.splitMapJoin('.', onNonMatch: (s) => s.isEmpty ? '' : s[0]);

  final core.Config? config;
  final OverlayWindow? overlayWindow;
  final ServerManager serverManager;

  const Devices({
    super.key,
    required this.serverManager,
    this.config,
    this.overlayWindow,
  });

  @override
  State<Devices> createState() => _DevicesState();
}

class _DevicesState extends State<Devices> {
  final selectedIds = <String>{};

  void Function() send(void Function(List<String>? ids) handler) => () {
        handler(
          selectedIds.isEmpty ? null : selectedIds.toList(growable: false),
        );
        // It's convenient in the common usage pattern to clear the selection
        // after sending a command; targeted commands tend to be one-off.
        setState(selectedIds.clear);
      };

  @override
  Widget build(BuildContext context) {
    List<Widget> deviceList() {
      if (widget.serverManager.serverState == null) {
        selectedIds.clear();
        return [];
      }

      // When we rebuild, we want to make sure we don't keep any IDs selected
      // that we lose the UI to deselect.
      // It could be more efficient to do this in the send handler.
      selectedIds.retainAll(widget.serverManager.serverState!.connections.keys);

      return [
        for (final MapEntry(key: id, value: connection)
            in widget.serverManager.serverState!.connections.entries)
          () {
            final selected = selectedIds.contains(id);

            return FadeIn(
              child: Material(
                type: MaterialType.circle,
                color: Colors.grey.shade300,
                shadowColor: Colors.blue,
                surfaceTintColor: Colors.white,
                clipBehavior: Clip.hardEdge,
                elevation: selected ? 2.0 : 0.0,
                child: InkWell(
                  onTap: () => setState(
                    () => (selected ? selectedIds.remove : selectedIds.add)(id),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AnimatedOpacity(
                        opacity: connection.screenOn ?? true ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 250),
                        child: const ColoredBox(color: Colors.black54),
                      ),
                      if (connection.foregroundPackage != null)
                        Center(
                          child: Text(
                            Devices.abbreviatePackageName(
                              connection.foregroundPackage!,
                            ),
                          ),
                        ),
                      AnimatedOpacity(
                        opacity: selected ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        child: ColoredBox(
                          color: RideHub.theme.primaryColor.withOpacity(.25),
                          child: const Icon(Icons.check),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }(),
      ];
    }

    List<Widget> controls() => [
          const SizedBox(height: 16.0),
          IconButtonTheme(
            data: IconButtonThemeData(
              style: IconButton.styleFrom(iconSize: 32.0),
            ),
            child: Row(
              children: [
                IconButton.outlined(
                  style: widget.overlayWindow == null
                      ? null
                      : const ButtonStyle(
                          backgroundColor:
                              MaterialStatePropertyAll(Colors.white),
                        ),
                  icon: const Icon(Icons.light_mode),
                  tooltip: 'Wake',
                  onPressed: send(widget.serverManager.wake),
                ),
                const SizedBox(width: 8.0),
                IconButton.filledTonal(
                  icon: const Icon(Icons.home),
                  tooltip: 'Home',
                  onPressed: send(widget.serverManager.home),
                ),
                const SizedBox(width: 8.0),
                IconButton.filled(
                  icon: const Icon(Icons.dark_mode),
                  tooltip: 'Sleep',
                  onPressed: send(widget.serverManager.sleep),
                ),
              ],
            ),
          ),
        ];

    return widget.overlayWindow == null
        ? Padding(
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
                    child: ListenableBuilder(
                      listenable: widget.serverManager,
                      builder: (context, _) => GridView.count(
                        crossAxisCount: 2,
                        padding: const EdgeInsets.all(8.0),
                        mainAxisSpacing: 8.0,
                        crossAxisSpacing: 8.0,
                        children: deviceList(),
                      ),
                    ),
                  ),
                ),
                ...controls(),
              ],
            ),
          )
        : ListenableBuilder(
            listenable: widget.serverManager,
            builder: (context, child) {
              if (widget.serverManager.serverState?.connections.isEmpty ??
                  true) {
                widget.overlayWindow!.update(const WindowParams(height: 0));
                return const SizedBox();
              }

              final dpr = MediaQuery.devicePixelRatioOf(context);

              final children = deviceList();
              widget.overlayWindow!.update(
                WindowParams(
                  // TODO: This update can conflict with and override the
                  // positioning update done by the drag handle, so we need to
                  // set the position here as well.
                  x: -(widget.config!.overlayPosition.dx * dpr).round(),
                  y: (widget.config!.overlayPosition.dy * dpr).round(),
                  height:
                      (((children.length / 2).ceil() * 82 + 80) * dpr).ceil(),
                  width: (160 * dpr).ceil(),
                ),
              );

              return Column(
                children: [
                  DragHandle(
                    config: widget.config!,
                    window: widget.overlayWindow!,
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: [
                        for (final child in children)
                          SizedBox.square(dimension: 74.0, child: child),
                      ],
                    ),
                  ),
                  child!,
                ],
              );
            },
            child: Column(children: controls()),
          );
  }
}

class DragHandle extends StatefulWidget {
  final core.Config config;
  final OverlayWindow window;
  const DragHandle({super.key, required this.config, required this.window});

  @override
  State<StatefulWidget> createState() => _DragHandleState();
}

class _DragHandleState extends State<DragHandle> {
  Offset? _panBasis;
  Offset _target = Offset.zero;

  @override
  void initState() {
    super.initState();
    _target = widget.config.overlayPosition;
    scheduleMicrotask(() {
      if (mounted) {
        _moveWindow();
      }
    });
  }

  @override
  void didUpdateWidget(covariant DragHandle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.config != oldWidget.config) {
      _target = widget.config.overlayPosition;
      _moveWindow();
    }
  }

  Future<void> _moveWindow() async {
    final target = _target;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    await widget.window.update(
      WindowParams(
        x: -(target.dx * dpr).round(),
        y: (target.dy * dpr).round(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onPanStart: (details) => _panBasis = details.globalPosition,
        onPanUpdate: (details) {
          // TODO: More intelligent downsampling based on how long it takes to
          // _moveWindow. We may be able to use backpressure logic.
          _target += (details.globalPosition - _panBasis!) * .1;
          _moveWindow();
        },
        onPanEnd: (_) => widget.config.overlayPosition = _target,
        child: const Icon(Icons.drag_handle),
      );
}

class FadeIn extends StatefulWidget {
  final Duration duration;
  final Widget child;

  const FadeIn({
    super.key,
    this.duration = const Duration(milliseconds: 250),
    required this.child,
  });

  @override
  State<StatefulWidget> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController animation;

  @override
  void initState() {
    super.initState();
    animation = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
  }

  @override
  void didUpdateWidget(covariant FadeIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    animation.duration = widget.duration;
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: animation, child: widget.child);
}
