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
  static const height = 80.0, iHeight = 80;
  static const fadeDuration = Duration(milliseconds: 300);
  static final theme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.grey.shade600,
    ),
    useMaterial3: true,
  );

  static void main(OverlayWindow window) {
    final sendPort = IsolateNameServer.lookupPortByName(Client.portName)!;
    final receivePort = ReceivePort('RideOverlay');
    sendPort.send([RideOverlay, receivePort.sendPort]);

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
  bool softSleep = false;

  @override
  void _onData(Message event) {
    switch (event) {
      case ['softSleep', final bool? value]:
        if (value == null) {
          widget.channel?.sink.add(['softSleep', softSleep]);
        } else if (value != softSleep) {
          () async {
            await widget.window?.update(
              WindowParams(
                height: value ? WindowParams.matchParent : RideOverlay.iHeight,
              ),
            );
            if (mounted) {
              setState(() => softSleep = value);
            }
          }();
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: RideOverlay.theme,
        home: Scaffold(
          backgroundColor: Colors.transparent,
          body: AnimatedOpacity(
            opacity: softSleep ? 1.0 : 0.0,
            duration: RideOverlay.fadeDuration,
            child: const ColoredBox(color: Colors.black),
          ),
          bottomNavigationBar: const BottomAppBar(
            shape: CircularNotchedRectangle(),
            height: RideOverlay.height,
            child: Text('BOTTOM'),
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
  static const size = 96.0, iSize = 96;

  static void main(_) {
    final sendPort = IsolateNameServer.lookupPortByName(Client.portName)!;
    final receivePort = ReceivePort('SleepButton');
    sendPort.send([SleepButton, receivePort.sendPort]);

    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: RideOverlay.theme,
        home: SleepButton(channel: IsolateChannel(receivePort, sendPort)),
      ),
    );
  }

  @override
  final IsolateChannel<Message>? channel;

  const SleepButton({super.key, this.channel});

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
  Widget build(BuildContext context) => FloatingActionButton.large(
        shape: const CircleBorder(),
        onPressed: widget.channel == null
            ? null
            : () => widget.channel!.sink.add(['softSleep', true]),
        child: Icon(softSleep ? Icons.light_mode : Icons.dark_mode),
      );
}
