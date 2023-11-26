import 'package:flutter_test/flutter_test.dart';

import 'package:ride_launcher/main.dart';

void main() {
  testWidgets('smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RideLauncher());
  });
}
