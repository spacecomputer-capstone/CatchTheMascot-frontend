import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/screens/1_home_screen.dart';
import '../../lib/utils/routes.dart';

void main() {
  testWidgets('HomeScreen has title, text, image, and button', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    // Verify title and text
    expect(find.text('Catch the Mascot'), findsOneWidget);
    expect(find.text('Welcome to Catch the Mascot!'), findsOneWidget);

    // Verify image exists
    expect(find.byType(Image), findsOneWidget);

    // Verify Start Game button exists
    expect(find.text('Start Game'), findsOneWidget);
  });

  testWidgets('Tapping Start Game navigates to LocationPermissionScreen route',
      (WidgetTester tester) async {
    final navigatorObserver = _MockNavigatorObserver();

    await tester.pumpWidget(MaterialApp(
      home: const HomeScreen(),
      routes: {
        Routes.locationPermission: (context) => const Scaffold(
              body: Center(child: Text('Location Permission Screen Placeholder')),
            ),
      },
      navigatorObservers: [navigatorObserver],
    ));

    // Tap the button
    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    // Verify new screen is shown
    expect(find.text('Location Permission Screen Placeholder'), findsOneWidget);
  });
}

class _MockNavigatorObserver extends NavigatorObserver {}