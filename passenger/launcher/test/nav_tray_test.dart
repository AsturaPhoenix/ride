import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:device_apps/device_apps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ride_launcher/ui/nav_tray.dart';

final Uint8List kEmptyPng = base64.decode('iVBORw0KGgoAAAANSUhEU'
    'gAAAAEAAAABCAYAAAAfFcSJAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwA'
    'ADsMAAA7DAcdvqGQAAAANSURBVBhXY2BgYGAAAAAFAAGKM+MAAAAAAElFTkSuQmCC');

class FakeApp with Fake implements Application {
  @override
  final String packageName;
  @override
  final String appName;

  const FakeApp({required this.packageName, required this.appName});
}

class FakeAppWithIcon with Fake implements ApplicationWithIcon {
  final FakeApp _base;

  @override
  get packageName => _base.packageName;
  @override
  get appName => _base.appName;
  @override
  get icon => kEmptyPng;

  const FakeAppWithIcon(this._base);
}

class FakeApplicationEvent with Fake implements ApplicationEvent {
  @override
  final ApplicationEventType event;
  @override
  final String packageName;

  const FakeApplicationEvent(this.event, this.packageName);
}

class FakeDeviceApps implements DeviceAppsImpl {
  List<FakeApp> apps = const [];
  final StreamController<ApplicationEvent> events = StreamController();

  @override
  Future<List<Application>> getInstalledApplications(
          {required bool includeAppIcons}) async =>
      includeAppIcons ? [for (final app in apps) FakeAppWithIcon(app)] : apps;

  @override
  Stream<ApplicationEvent> listenToAppsChanges() => events.stream;
}

void main() {
  Future<void> setUpWithTester(WidgetTester tester) async {
    // Image precache has to happen in a real async context.
    late final Future<void> precache;
    await tester.pumpWidget(Builder(builder: (context) {
      precache =
          tester.runAsync(() => precacheImage(MemoryImage(kEmptyPng), context));
      return const SizedBox();
    }));
    await precache;
  }

  testWidgets('nav tray displays allowed apps', (WidgetTester tester) async {
    await setUpWithTester(tester);

    final apps = FakeDeviceApps();
    apps.apps = const [
      FakeApp(
        packageName: 'com.spotify.music',
        appName: 'Spotify',
      )
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NavTray(deviceApps: apps),
      ),
    ));
    await tester.pump();

    expect(find.text('Music'), findsOneWidget);
  });

  testWidgets('nav tray responds to app updates', (WidgetTester tester) async {
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
}
