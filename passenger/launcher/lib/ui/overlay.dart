import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:overlay_window/overlay_window.dart';
import 'package:ride_shared/protocol.dart';
import 'package:stream_channel/isolate_channel.dart';
import 'package:stream_channel/stream_channel.dart';

import '../core/client.dart';

mixin ChannelListenerWidget<T> on StatefulWidget {
  StreamChannel<T>? get channel;
}

mixin ChannelListenerStateMixin<T, W extends ChannelListenerWidget<T>>
    on State<W> {
  StreamSubscription<T>? _subscription;

  void _onData(T event);

  @override
  void initState() {
    super.initState();
    _subscription = widget.channel?.stream.listen(_onData);
  }

  @override
  void didUpdateWidget(W oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.channel != oldWidget.channel) {
      _subscription?.cancel();
      oldWidget.channel?.sink.close();
      _subscription = widget.channel?.stream.listen(_onData);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    widget.channel?.sink.close();
    super.dispose();
  }
}

class RideOverlay extends StatefulWidget with ChannelListenerWidget<Message> {
  static const height = 80,
      shadowPadding = 16,
      windowHeight = height + shadowPadding;
  static final colors = ColorScheme.fromSeed(
    seedColor: Colors.grey.shade500,
    primary: Colors.grey.shade500,
    secondary: Colors.grey.shade400,
  );
  static final theme = ThemeData(
    colorScheme: colors,
    useMaterial3: true,
    bottomAppBarTheme: BottomAppBarTheme(color: colors.primary),
    floatingActionButtonTheme:
        FloatingActionButtonThemeData(backgroundColor: colors.secondary),
  );
  static final darkTheme = theme.copyWith(
    shadowColor: Colors.white,
    floatingActionButtonTheme: theme.floatingActionButtonTheme
        .copyWith(foregroundColor: Colors.cyanAccent),
  );

  static void main(OverlayWindow window) {
    final sendPort = IsolateNameServer.lookupPortByName(Client.portName)!;
    final receivePort = ReceivePort('RideOverlay');
    sendPort.send(['RideOverlay', receivePort.sendPort]);

    runApp(
      RideOverlay(
        window: window,
        channel: IsolateChannel(receivePort, sendPort),
      ),
    );
  }

  final OverlayWindow? window;
  @override
  final IsolateChannel<Message>? channel;

  const RideOverlay({super.key, this.window, this.channel});

  @override
  RideOverlayState createState() => RideOverlayState();
}

class RideOverlayState extends State<RideOverlay>
    with ChannelListenerStateMixin<Message, RideOverlay> {
  @override
  void _onData(Message event) {
    switch (event) {
      // TODO
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: RideOverlay.theme,
        home: Scaffold(
          backgroundColor: Colors.transparent,
          bottomNavigationBar: BottomAppBar(
            shape: const CircularNotchedRectangle(),
            height: RideOverlay.height.toDouble(),
            child: const Text('BOTTOM'),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          floatingActionButton: const Visibility(
            visible: false,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: SleepButton(),
          ),
        ),
      );
}

class SleepButton extends StatefulWidget with ChannelListenerWidget<Message> {
  static const size = 96, windowSize = size + 2 * RideOverlay.shadowPadding;

  static void main(_) {
    final sendPort = IsolateNameServer.lookupPortByName(Client.portName)!;
    final receivePort = ReceivePort('SleepButton');
    sendPort.send(['SleepButton', receivePort.sendPort]);

    runApp(
      SleepButton(
        channel: IsolateChannel(receivePort, sendPort),
        standalone: true,
      ),
    );
  }

  final bool standalone;
  @override
  final IsolateChannel<Message>? channel;

  const SleepButton({super.key, this.channel, this.standalone = false});

  @override
  SleepButtonState createState() => SleepButtonState();
}

class SleepButtonState extends State<SleepButton>
    with ChannelListenerStateMixin<Message, SleepButton> {
  bool softSleep = false;

  @override
  void _onData(Message event) {
    switch (event) {
      case ['softSleep', final bool value]:
        setState(() => softSleep = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget result = FloatingActionButton.large(
      shape: const CircleBorder(),
      onPressed: widget.channel == null
          ? null
          : () => widget.channel!.sink.add(['softSleep', !softSleep]),
      child: const Icon(Icons.power_settings_new),
    );

    if (widget.standalone) {
      result = MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: RideOverlay.theme,
        darkTheme: RideOverlay.darkTheme,
        themeAnimationDuration: NightShade.fadeDuration,
        themeMode: softSleep ? ThemeMode.dark : ThemeMode.light,
        home: Padding(
          padding: EdgeInsets.all(RideOverlay.shadowPadding.toDouble()),
          child: result,
        ),
      );
    }

    return result;
  }
}

/// Having this be a separate window is a bit unfortunate, but seems to be one
/// of the few ways to change the touch occlusion without visual artifacts.
///
/// Resizing the window changes the touch occlusion but results in the status
/// bar being drawn in the incorrect position for a frame each resize.
class NightShade extends StatefulWidget with ChannelListenerWidget<Message> {
  static const fadeDuration = Duration(milliseconds: 300);

  static void main(OverlayWindow window) {
    final sendPort = IsolateNameServer.lookupPortByName(Client.portName)!;
    final receivePort = ReceivePort('NightShade');
    sendPort.send(['NightShade', receivePort.sendPort]);

    runApp(
      NightShade(
        window: window,
        channel: IsolateChannel(receivePort, sendPort),
      ),
    );
  }

  final OverlayWindow? window;

  @override
  final IsolateChannel<Message>? channel;

  const NightShade({super.key, this.window, this.channel});

  @override
  NightShadeState createState() => NightShadeState();
}

class NightShadeState extends State<NightShade>
    with ChannelListenerStateMixin<Message, NightShade> {
  bool softSleep = false;

  @override
  void initState() {
    super.initState();
    widget.window?.setVisibility(OverlayWindow.invisible);
  }

  @override
  void didUpdateWidget(covariant NightShade oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(widget.window == oldWidget.window);
  }

  @override
  void _onData(Message event) {
    switch (event) {
      case ['softSleep', final bool value]:
        () async {
          if (value) {
            await widget.window?.setVisibility(OverlayWindow.visible);
          }
          if (mounted) {
            setState(() => softSleep = value);
          }
        }();
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: AnimatedOpacity(
          opacity: softSleep ? 1.0 : 0.0,
          duration: NightShade.fadeDuration,
          onEnd: () {
            if (!softSleep) {
              widget.window?.setVisibility(OverlayWindow.invisible);
            }
          },
          child: const ColoredBox(
            color: Colors.black,
            child: SizedBox.expand(),
          ),
        ),
      );
}
