import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dms_demo/choose_dms_demo.dart';

void main() {
  testWidgets('Check if buttons render and tap works', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChooseDmsDemo(),
        ),
      ),
    );

    // Check that both buttons are present
    expect(find.text('Start a Trip'), findsOneWidget);
    expect(find.text('Run Model with Image'), findsOneWidget);

    // Tap "Start a Trip" button
    await tester.tap(find.text('Start a Trip'));
    await tester.pumpAndSettle(); // Wait for navigation to complete

    // You would now normally verify if RunModelByCameraDemo screen shows something unique.
    // For example, if that screen has a title like "Camera Demo", check for it here:
    // expect(find.text('Camera Demo'), findsOneWidget);
  });
}
