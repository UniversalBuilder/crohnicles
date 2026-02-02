import 'package:flutter_test/flutter_test.dart';
import 'package:crohnicles/ml/model_manager.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Setup sqflite for testing
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('ModelManager Tests', () {
    late ModelManager modelManager;

    setUp(() {
      modelManager = ModelManager();
    });

    test('ModelManager initialization should complete', () async {
      await modelManager.initialize();
      // Even without models, it should initialize
      expect(modelManager.isReady, isNotNull);
    });

    test('Risk prediction structure is correct', () {
      final prediction = RiskPrediction(
        symptomType: 'pain',
        riskScore: 0.8,
        confidence: 0.9,
        topFactors: [],
        explanation: 'High risk',
        similarMealIds: [],
      );

      expect(prediction.riskLevel, 'high');
      expect(prediction.riskEmoji, '🔴');
    });
  });
}
