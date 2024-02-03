import 'package:app_widget_host/app_widget_host_platform_interface.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_launcher/fake/app_widget_host.dart';
import 'package:ride_launcher/fake/device_apps.dart';

import 'package:ride_launcher/ui/launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    AppWidgetHostPlatform.instance = FakeAppWidgetHost();
  });

  testWidgets('smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(RideLauncher());
  });

  testWidgets('does not exit on back button', (WidgetTester tester) async {
    await tester.pumpWidget(RideLauncher());

    expect(
        await (tester.state(find.byType(WidgetsApp)) as WidgetsBindingObserver)
            .didPopRoute(),
        // didPopRoute => false implies an app exit
        isTrue);
  });

  testWidgets('back from submenu', (WidgetTester tester) async {
    final controller = RideLauncherController();
    await tester.pumpWidget(
      RideLauncher(
        controller: controller,
        deviceApps: FakeDeviceApps()..apps = FakeDeviceApps.standardApps,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Video'));
    await tester.pumpAndSettle();

    expect(find.text('Music'), findsNothing);
    expect(find.text('Video'), findsOneWidget);

    await (tester.state(find.byType(WidgetsApp)) as WidgetsBindingObserver)
        .didPopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Video'), findsOneWidget);
  });

  testWidgets('home from submenu', (WidgetTester tester) async {
    final controller = RideLauncherController();
    await tester.pumpWidget(
      RideLauncher(
        controller: controller,
        deviceApps: FakeDeviceApps()..apps = FakeDeviceApps.standardApps,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Video'));
    await tester.pumpAndSettle();

    expect(find.text('Music'), findsNothing);
    expect(find.text('Video'), findsOneWidget);

    controller.home();
    await tester.pumpAndSettle();

    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Video'), findsOneWidget);
  });
}
