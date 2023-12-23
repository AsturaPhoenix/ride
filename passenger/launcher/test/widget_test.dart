import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ride_launcher/main.dart';

void main() {
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
}
