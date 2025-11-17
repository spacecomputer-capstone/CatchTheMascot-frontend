import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/screens/2_location_permission_screen.dart';

void main() {
  testWidgets('LocationPermissionScreen renders correctly',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: LocationPermissionScreen(),
    ));

    // Verify title
    expect(find.text('Allow Location'), findsOneWidget);

    // Verify placeholder text
    expect(find.text('Location Permission Screen Placeholder'), findsOneWidget);
  });
}
