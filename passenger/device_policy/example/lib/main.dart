import 'package:flutter/material.dart';
import 'dart:async';

import 'package:ride_device_policy/ride_device_policy.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<Duration?>? _screenOffTimeout;

  @override
  void initState() {
    super.initState();

    _screenOffTimeout = RideDevicePolicy.getScreenOffTimeout();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: FutureBuilder(
          future: _screenOffTimeout,
          builder: (context, snapshot) =>
              Text('Screen off timeout: ${snapshot.data}'),
        ),
      ),
    );
  }
}
