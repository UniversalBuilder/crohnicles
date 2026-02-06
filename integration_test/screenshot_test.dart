import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:crohnicles/main.dart' as app;

/// Integration test pour capturer des screenshots automatiques
/// Utilise le simulateur/émulateur pour générer des images pour le README
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Screenshots Automatiques', () {
    testWidgets('Screenshot 1: Page d\'accueil (Timeline)', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Attendre le chargement complet
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Capturer le screenshot
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      
      await _takeScreenshot(binding, '01_timeline');
    });

    testWidgets('Screenshot 2: Compositeur de repas', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Ouvrir le menu du bas
      final fabFinder = find.byType(FloatingActionButton);
      await tester.tap(fabFinder);
      await tester.pumpAndSettle();

      // Cliquer sur "Repas"
      final mealButtonFinder = find.text('Repas');
      if (mealButtonFinder.evaluate().isNotEmpty) {
        await tester.tap(mealButtonFinder);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        await _takeScreenshot(binding, '02_meal_composer');
      }
    });

    testWidgets('Screenshot 3: Page Insights', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Naviguer vers Insights (onglet 2)
      final insightsFinder = find.byIcon(Icons.insights);
      if (insightsFinder.evaluate().isNotEmpty) {
        await tester.tap(insightsFinder);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        await _takeScreenshot(binding, '03_insights');
      }
    });

    testWidgets('Screenshot 4: Calendrier', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Naviguer vers Calendrier (onglet 1)
      final calendarFinder = find.byIcon(Icons.calendar_month);
      if (calendarFinder.evaluate().isNotEmpty) {
        await tester.tap(calendarFinder);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        await _takeScreenshot(binding, '04_calendar');
      }
    });

    testWidgets('Screenshot 5: Settings & About', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Ouvrir le drawer ou naviguer vers Settings
      final menuFinder = find.byIcon(Icons.settings);
      if (menuFinder.evaluate().isNotEmpty) {
        await tester.tap(menuFinder);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        await _takeScreenshot(binding, '05_settings');
      }
    });
  });
}

/// Capture un screenshot et le sauvegarde dans docs/screenshots/
Future<void> _takeScreenshot(IntegrationTestWidgetsFlutterBinding binding, String name) async {
  try {
    // Créer le dossier si nécessaire
    final directory = Directory('docs/screenshots');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    // Capturer et sauvegarder
    await binding.takeScreenshot(name);
    debugPrint('✅ Screenshot capturé: $name.png');
  } catch (e) {
    debugPrint('❌ Erreur lors de la capture: $e');
  }
}
