import 'dart:async';

import 'package:flutter/material.dart';
import 'package:overlay_window/overlay_window.dart';

import '../core/config.dart' as core;
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
  final selected = <String>{};

  void Function() send(void Function(List<String>? ids) handler) =>
      () => handler(selected.isEmpty ? null : selected.toList(growable: false));

  @override
  Widget build(BuildContext context) {
    List<Widget> deviceList() {
      if (widget.serverManager.serverState == null) {
        selected.clear();
        return [];
      }

      // When we rebuild, we want to make sure we don't keep any IDs selected
      // that we lose the UI to deselect.
      selected.retainAll(widget.serverManager.serverState!.connections.keys);

      return [
        for (final MapEntry(key: id, value: connection)
            in widget.serverManager.serverState!.connections.entries)
          TweenAnimationBuilder(
            tween: ColorTween(
              // Although ColorTween treats null as transparent,
              // TweenAnimationBuilder interprets it as meaning
              // the animation should start at the end value.
              begin: Colors.white.withOpacity(0.0),
              end: connection.screenOn != false ? Colors.white : Colors.grey,
            ),
            duration: const Duration(milliseconds: 250),
            builder: (context, value, child) => ColorFiltered(
              colorFilter: _colorFilterMultiply(value!),
              child: child,
            ),
            child: Material(
              color: Colors.grey.shade300,
              shadowColor: Colors.blue,
              surfaceTintColor: Colors.white,
              shape: const CircleBorder(),
              clipBehavior: Clip.hardEdge,
              elevation: selected.contains(id) ? 4.0 : 0.0,
              child: InkWell(
                onTap: () =>
                    setState(() => selected.remove(id) || selected.add(id)),
                child: connection.foregroundPackage == null
                    ? null
                    : Center(
                        child: Text(
                          Devices.abbreviatePackageName(
                            connection.foregroundPackage!,
                          ),
                        ),
                      ),
              ),
            ),
          ),
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
