import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/screens/2_location_permission_screen.dart';

void main() {
  testWidgets('LocationPermissionScreen renders correctly',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: LocationPermissionScreen(),
    ));

    // Verify AppBar title
    expect(find.text('Allow Location'), findsOneWidget);

    // Verify body text
    expect(find.text('Catch the Mascot needs your location to play.'),
        findsOneWidget);

    // Verify button
    expect(find.text('Enable Location'), findsOneWidget);
  });
}