import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/screens/1_home_screen.dart';
import 'package:app/utils/routes.dart';

void main() {
  testWidgets('HomeScreen shows mascot, forms, and Start Game button', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    // Screen title
    expect(find.text('Catch the Mascot'), findsOneWidget);

    // Welcome text
    expect(find.text('Welcome to Catch the Mascot!'), findsOneWidget);

    // At least one image (background mascot)
    expect(find.byType(Image), findsWidgets);

    // Register appears twice (title + button)
    expect(find.text('Register'), findsNWidgets(2));

    // Log In appears twice (title + button)
    expect(find.text('Log In'), findsNWidgets(2));

    // Start Game exists
    expect(find.text('Start Game'), findsOneWidget);
  });

  testWidgets('Start Game button navigates to location permission screen',
      (WidgetTester tester) async {
    final navigatorObserver = _MockNavigatorObserver();

    await tester.pumpWidget(MaterialApp(
      home: const HomeScreen(),
      routes: {
        Routes.locationPermission: (context) =>
            const Scaffold(body: Center(child: Text('Location Permission Screen Placeholder'))),
      },
      navigatorObservers: [navigatorObserver],
    ));

    // Ensure Start Game button is visible inside scroll view
    await tester.ensureVisible(find.text('Start Game'));
    await tester.pumpAndSettle();

    // Tap
    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    // Verify navigation
    expect(find.text('Location Permission Screen Placeholder'), findsOneWidget);
  });
}

class _MockNavigatorObserver extends NavigatorObserver {}