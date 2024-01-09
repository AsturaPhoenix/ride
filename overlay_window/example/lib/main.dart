import 'package:flutter/material.dart';
import 'dart:async';

import 'package:overlay_window/overlay_window.dart';

void main() {
  runApp(MyApp(
      overlayWindow: OverlayWindow.create(overlayMain, const WindowParams())));
}

void overlayMain() {
  runApp(const MaterialApp(home: Text('OVERLAY')));
}

class MyApp extends StatefulWidget {
  final Future<OverlayWindow>? overlayWindow;
  const MyApp({super.key, this.overlayWindow});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void dispose() {
    (() async => (await widget.overlayWindow)?.destroy())();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: const Text('Body'),
      ),
    );
  }
}
