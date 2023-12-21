import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_launcher/core/client.dart';
import 'package:ride_launcher/core/config.dart';

import 'package:ride_launcher/main.dart';

class FakeConfig implements Config {
  @override
  String? assetsVersion;

  @override
  String id = 'fake-device';

  @override
  int serverPort = 0;
}

void main() {
  testWidgets('smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(RideLauncher(
      clientManager: ClientManager(FakeConfig()),
    ));
  });

  testWidgets('does not exit on back button', (WidgetTester tester) async {
    await tester.pumpWidget(RideLauncher(
      clientManager: ClientManager(FakeConfig()),
    ));

    expect(
        await (tester.state(find.byType(WidgetsApp)) as WidgetsBindingObserver)
            .didPopRoute(),
        // didPopRoute => false implies an app exit
        isTrue);
  });
}
