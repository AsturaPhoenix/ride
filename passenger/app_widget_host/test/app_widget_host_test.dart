import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_widget_host/app_widget_host.dart';

void main() {
  testWidgets('smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppWidgetHostView(appWidgetId: 0),
        ),
      ),
    );
  });
}
