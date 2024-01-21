import 'package:flutter/material.dart';

import 'package:app_widget_host/app_widget_host.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: const Center(
          child: AppWidgetHostView(appWidgetId: 0),
        ),
      ),
    );
  }
}
