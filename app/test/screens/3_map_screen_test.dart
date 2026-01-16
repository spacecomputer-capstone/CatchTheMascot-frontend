import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// ------------------------------------------------------------
  /// 1. Basic smoke test: widget builds and shows loading state
  /// ------------------------------------------------------------
  testWidgets('MapScreen builds and shows loading spinner',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: MapScreen(),
          ),
        );

        // Scaffold is present
        expect(find.byType(Scaffold), findsOneWidget);

        // Initial loading spinner (because async map init has not completed)
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

  /// ------------------------------------------------------------
  /// 2. Widget can rebuild safely (tests setState paths indirectly)
  /// ------------------------------------------------------------
  testWidgets('MapScreen can rebuild safely without platform channels',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: MapScreen(),
          ),
        );

        // Second pump simulates rebuild
        await tester.pump(const Duration(milliseconds: 100));

        // Still safe
        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

  /// ------------------------------------------------------------
  /// 3. Ensures no crashes occur even with multiple frames
  /// ------------------------------------------------------------
  testWidgets('MapScreen stays stable across multiple frames',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: MapScreen(),
          ),
        );

        // Pump multiple frames to ensure no async exception crashes the test
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        // Still alive
        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
}
