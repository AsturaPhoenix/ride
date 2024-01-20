import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:device_apps/device_apps.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ui/nav_tray.dart';

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
  static const standardApps = [
    FakeApp(
      packageName: 'com.spotify.music',
      appName: 'Spotify',
    ),
    FakeApp(
      packageName: 'com.netflix.mediaclient',
      appName: 'Netflix',
    ),
    FakeApp(
      packageName: 'com.amazon.youtube_apk',
      appName: 'YouTube',
    ),
    FakeApp(
      packageName: 'com.android.chrome',
      appName: 'Chrome',
    ),
  ];

  List<FakeApp> apps = const [];
  final StreamController<ApplicationEvent> events = StreamController();

  Future<dynamic> close() => events.close();

  @override
  Future<List<Application>> getInstalledApplications({
    required bool includeAppIcons,
  }) async =>
      includeAppIcons ? [for (final app in apps) FakeAppWithIcon(app)] : apps;

  @override
  Stream<ApplicationEvent> listenToAppsChanges() => events.stream;
}
