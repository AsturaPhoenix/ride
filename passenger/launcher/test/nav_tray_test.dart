import 'package:device_apps/device_apps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ride_launcher/fake/device_apps.dart';
import 'package:ride_launcher/ui/nav_tray.dart';

void main() {
  group('nav tray', () {
    Future<void> setUpWithTester(WidgetTester tester) async {
      // Image precache has to happen in a real async context.
      late final Future<void> precache;
      await tester.pumpWidget(Builder(builder: (context) {
        precache = tester
            .runAsync(() => precacheImage(MemoryImage(kEmptyPng), context));
        return const SizedBox();
      }));
      await precache;
    }

    testWidgets('displays allowed apps', (WidgetTester tester) async {
      await setUpWithTester(tester);

      final apps = FakeDeviceApps()..apps = FakeDeviceApps.standardApps;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NavTray(deviceApps: apps),
        ),
      ));
      await tester.pump();

      expect(find.text('Music'), findsOneWidget);
    });

    testWidgets('responds to app updates', (WidgetTester tester) async {
      await setUpWithTester(tester);

      final apps = FakeDeviceApps();
      apps.apps = [
        FakeApp(
          packageName: RideAppCategory.music.apps.first,
          appName: 'music app',
        )
      ];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NavTray(deviceApps: apps),
        ),
      ));
      await tester.pump();

      expect(find.text('Video'), findsNothing);

      final newApp = RideAppCategory.video.apps.first;
      apps.apps += [
        FakeApp(
          packageName: newApp,
          appName: 'video app',
        )
      ];
      apps.events
          .add(FakeApplicationEvent(ApplicationEventType.installed, newApp));
      await tester.pump();

      expect(find.text('Video'), findsOneWidget);
    });

    testWidgets('hero animation', (WidgetTester tester) async {
      await setUpWithTester(tester);

      final controller = NavTrayController();
      final deviceApps = FakeDeviceApps()..apps = FakeDeviceApps.standardApps;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NavTray(
              controller: controller,
              deviceApps: deviceApps,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Video'));
      await tester.pumpAndSettle();

      expect(find.text('Music'), findsNothing);
      expect(find.text('Video'), findsOneWidget);
      expect(find.text('Netflix'), findsOneWidget);
      expect(find.text('YouTube'), findsOneWidget);

      controller.home();
      await tester.pumpAndSettle();

      expect(find.text('Music'), findsOneWidget);
      expect(find.text('Video'), findsOneWidget);
    });
  });
}
