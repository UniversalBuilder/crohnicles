import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:crohnicles/meal_composer_dialog.dart';
import 'package:crohnicles/app_theme.dart';

void main() {
  group('MealComposerDialog Widget Tests', () {
    testWidgets('Dialog opens with Repas selected by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const MealComposerDialog(),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Composer un Repas'), findsOneWidget);
      expect(find.text('Repas'), findsOneWidget);
      expect(find.text('Snack'), findsOneWidget);
    });

    testWidgets('SegmentedButton toggles between Repas and Snack', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const MealComposerDialog(),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap Snack segment
      await tester.tap(find.text('Snack'));
      await tester.pumpAndSettle();

      // Verify button text changed
      expect(find.text('Valider le Snack'), findsOneWidget);
    });

    testWidgets('TabBar shows all three tabs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const MealComposerDialog(),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Scanner'), findsOneWidget);
      expect(find.text('Rechercher'), findsOneWidget);
      expect(find.text('Créer'), findsOneWidget);
    });

    testWidgets('Returns null when cancelled', (tester) async {
      dynamic result;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showDialog(
                    context: context,
                    builder: (_) => const MealComposerDialog(),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });
  });

  group('MealComposerDialog Golden Tests', () {
    testGoldens('Dialog renders correctly on open', (tester) async {
      await loadAppFonts();
      
      await tester.pumpWidgetBuilder(
        const MealComposerDialog(),
        surfaceSize: const Size(600, 700),
        wrapper: materialAppWrapper(
          theme: AppTheme.lightTheme,
        ),
      );

      await screenMatchesGolden(tester, 'meal_composer_dialog_initial');
    });

    testGoldens('Dialog shows Snack mode', (tester) async {
      await loadAppFonts();
      
      final widget = Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const MealComposerDialog(),
            ),
            child: const Text('Open'),
          );
        },
      );

      await tester.pumpWidgetBuilder(
        widget,
        surfaceSize: const Size(800, 900),
        wrapper: materialAppWrapper(theme: AppTheme.lightTheme),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Snack'));
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, 'meal_composer_dialog_snack_mode');
    });
  });
}
