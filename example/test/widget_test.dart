import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gfmc_flutter_example/main.dart';

void main() {
  testWidgets('Shows the open-hub button', (WidgetTester tester) async {
    await tester.pumpWidget(const ExampleApp());

    expect(find.text('Status: not initialized'), findsOneWidget);
    expect(
      find.widgetWithText(ElevatedButton, 'Open minicinema hub'),
      findsOneWidget,
    );
  });
}
