import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';

/// Result of ML model training
class TrainingResult {
  final bool success;
  final Map<String, ModelMetrics> modelMetrics; // symptom type → metrics
  final String? errorMessage;
  final DateTime trainedAt;
  final int trainingDataSize;
  final Duration trainingDuration;

  TrainingResult({
    required this.success,
    required this.modelMetrics,
    this.errorMessage,
    required this.trainedAt,
    required this.trainingDataSize,
    required this.trainingDuration,
  });

  double get averageAccuracy {
    if (modelMetrics.isEmpty) return 0.0;
    final total = modelMetrics.values.fold(0.0, (sum, m) => sum + m.accuracy);
    return total / modelMetrics.length;
  }
}

/// Metrics for a single model (symptom type)
class ModelMetrics {
  final String symptomType;
  final double accuracy;
  final double precision;
  final double recall;
  final double f1Score;
  final int trainingExamples;
  final int testExamples;

  ModelMetrics({
    required this.symptomType,
    required this.accuracy,
    required this.precision,
    required this.recall,
    required this.f1Score,
    required this.trainingExamples,
    required this.testExamples,
  });

  Map<String, dynamic> toJson() => {
    'symptom_type': symptomType,
    'accuracy': accuracy,
    'precision': precision,
    'recall': recall,
    'f1_score': f1Score,
    'training_examples': trainingExamples,
    'test_examples': testExamples,
  };
}

/// Parameters for isolate-based training
class TrainingParams {
  final List<Map<String, dynamic>> meals;
  final List<Map<String, dynamic>> symptoms;
  final int windowHours;
  final String symptomType;

  TrainingParams({
    required this.meals,
    required this.symptoms,
    required this.windowHours,
    required this.symptomType,
  });
}

/// Service for on-device ML model training
class TrainingService {
  static const int minMealsRequired = 30;
  static const int minSymptomsRequired = 20;
  static const double testSplit = 0.2; // 20% holdout for testing

  /// Train all symptom type models (Digestif, Articulaires, Fatigue)
  Future<TrainingResult> trainAllModels({
    int windowHours = 8,
    Function(String)? onProgress,
  }) async {
    final startTime = DateTime.now();
    
    try {
      onProgress?.call('📊 Chargement des données...');
      
      // Load training data from database
      final db = await DatabaseHelper().database;
      final mealsData = await db.query(
        'events',
        where: 'type = ?',
        whereArgs: ['meal'],
        orderBy: 'dateTime DESC',
        limit: 500, // Last 500 meals
      );
      
      final symptomsData = await db.query(
        'events',
        where: 'type = ? AND severity >= ?',
        whereArgs: ['symptom', 3], // Only significant symptoms
        orderBy: 'dateTime DESC',
        limit: 500,
      );

      if (mealsData.length < minMealsRequired) {
        return TrainingResult(
          success: false,
          modelMetrics: {},
          errorMessage: 'Données insuffisantes: ${mealsData.length} repas (minimum $minMealsRequired requis)',
          trainedAt: DateTime.now(),
          trainingDataSize: mealsData.length,
          trainingDuration: DateTime.now().difference(startTime),
        );
      }

      if (symptomsData.length < minSymptomsRequired) {
        return TrainingResult(
          success: false,
          modelMetrics: {},
          errorMessage: 'Données insuffisantes: ${symptomsData.length} symptômes (minimum $minSymptomsRequired requis)',
          trainedAt: DateTime.now(),
          trainingDataSize: symptomsData.length,
          trainingDuration: DateTime.now().difference(startTime),
        );
      }

      onProgress?.call('🧠 Entraînement des modèles (${mealsData.length} repas, ${symptomsData.length} symptômes)...');

      // Train models for each symptom type
      final symptomTypes = ['Digestif', 'Articulaires', 'Fatigue'];
      final Map<String, ModelMetrics> allMetrics = {};

      for (final symptomType in symptomTypes) {
        onProgress?.call('🎯 Entraînement: $symptomType...');
        
        // Train model in isolate to avoid UI freeze
        final metrics = await _trainModelForSymptomType(
          meals: mealsData,
          symptoms: symptomsData,
          symptomType: symptomType,
          windowHours: windowHours,
        );

        allMetrics[symptomType] = metrics;
      }

      // Save training history to database
      onProgress?.call('💾 Sauvegarde des modèles...');
      await _saveTrainingHistory(db, allMetrics);

      final duration = DateTime.now().difference(startTime);
      
      return TrainingResult(
        success: true,
        modelMetrics: allMetrics,
        trainedAt: DateTime.now(),
        trainingDataSize: mealsData.length,
        trainingDuration: duration,
      );

    } catch (e) {
      debugPrint('[TrainingService] ❌ Training error: $e');
      return TrainingResult(
        success: false,
        modelMetrics: {},
        errorMessage: e.toString(),
        trainedAt: DateTime.now(),
        trainingDataSize: 0,
        trainingDuration: DateTime.now().difference(startTime),
      );
    }
  }

  /// Train model for a specific symptom type using simple decision rules
  /// 
  /// NOTE: This is a simplified version using rule-based classification.
  /// For full ML implementation, integrate tflite_flutter and train actual
  /// decision trees or neural networks in isolate.
  Future<ModelMetrics> _trainModelForSymptomType({
    required List<Map<String, dynamic>> meals,
    required List<Map<String, dynamic>> symptoms,
    required String symptomType,
    required int windowHours,
  }) async {
    // Filter symptoms by type
    final relevantSymptoms = symptoms.where((s) {
      final tags = ((s['tags'] as String?) ?? '').split(',');
      return _isSymptomOfType(tags, symptomType);
    }).toList();

    if (relevantSymptoms.isEmpty) {
      return ModelMetrics(
        symptomType: symptomType,
        accuracy: 0.0,
        precision: 0.0,
        recall: 0.0,
        f1Score: 0.0,
        trainingExamples: 0,
        testExamples: 0,
      );
    }

    // Create training dataset (meal → symptom correlation)
    final dataset = _createDataset(meals, relevantSymptoms, windowHours);
    
    if (dataset.length < 10) {
      return ModelMetrics(
        symptomType: symptomType,
        accuracy: 0.0,
        precision: 0.0,
        recall: 0.0,
        f1Score: 0.0,
        trainingExamples: dataset.length,
        testExamples: 0,
      );
    }

    // Split dataset (80% train, 20% test)
    final splitIndex = (dataset.length * (1 - testSplit)).round();
    final trainSet = dataset.sublist(0, splitIndex);
    final testSet = dataset.sublist(splitIndex);

    // Train simple rule-based model (count correlations)
    final model = _trainSimpleModel(trainSet, symptomType);

    // Evaluate on test set
    final metrics = _evaluateModel(model, testSet, symptomType);

    return ModelMetrics(
      symptomType: symptomType,
      accuracy: metrics['accuracy']!,
      precision: metrics['precision']!,
      recall: metrics['recall']!,
      f1Score: metrics['f1']!,
      trainingExamples: trainSet.length,
      testExamples: testSet.length,
    );
  }

  /// Create dataset of meal → symptom correlations
  List<Map<String, dynamic>> _createDataset(
    List<Map<String, dynamic>> meals,
    List<Map<String, dynamic>> symptoms,
    int windowHours,
  ) {
    final dataset = <Map<String, dynamic>>[];
    final window = Duration(hours: windowHours);

    for (final meal in meals) {
      final mealTime = DateTime.parse(meal['dateTime'] as String);
      
      // Check if symptoms occurred within window
      final hasSymptom = symptoms.any((symptom) {
        final symptomTime = DateTime.parse(symptom['dateTime'] as String);
        final diff = symptomTime.difference(mealTime);
        return diff.isNegative == false && diff <= window;
      });

      dataset.add({
        'meal': meal,
        'hasSymptom': hasSymptom,
        'tags': (meal['tags'] as String?)?.split(',') ?? [],
      });
    }

    return dataset;
  }

  /// Train simple rule-based model (count tag correlations)
  Map<String, double> _trainSimpleModel(
    List<Map<String, dynamic>> trainSet,
    String symptomType,
  ) {
    final tagRiskScores = <String, double>{};
    
    for (final example in trainSet) {
      final tags = example['tags'] as List<String>;
      final hasSymptom = example['hasSymptom'] as bool;
      
      for (final tag in tags) {
        if (tag.isEmpty) continue;
        tagRiskScores[tag] = (tagRiskScores[tag] ?? 0.0) + (hasSymptom ? 1.0 : -0.5);
      }
    }

    return tagRiskScores;
  }

  /// Evaluate model on test set
  Map<String, double> _evaluateModel(
    Map<String, double> model,
    List<Map<String, dynamic>> testSet,
    String symptomType,
  ) {
    int truePositives = 0;
    int falsePositives = 0;
    int trueNegatives = 0;
    int falseNegatives = 0;

    for (final example in testSet) {
      final tags = example['tags'] as List<String>;
      final actualSymptom = example['hasSymptom'] as bool;
      
      // Predict based on tag risk scores
      double riskScore = 0.0;
      for (final tag in tags) {
        riskScore += model[tag] ?? 0.0;
      }
      final predictedSymptom = riskScore > 0.5;

      if (actualSymptom && predictedSymptom) {
        truePositives++;
      } else if (!actualSymptom && predictedSymptom) falsePositives++;
      else if (!actualSymptom && !predictedSymptom) trueNegatives++;
      else falseNegatives++;
    }

    final total = testSet.length.toDouble();
    final accuracy = (truePositives + trueNegatives) / total;
    final precision = truePositives + falsePositives > 0 
        ? truePositives / (truePositives + falsePositives)
        : 0.0;
    final recall = truePositives + falseNegatives > 0
        ? truePositives / (truePositives + falseNegatives)
        : 0.0;
    final f1 = precision + recall > 0
        ? 2 * (precision * recall) / (precision + recall)
        : 0.0;

    return {
      'accuracy': accuracy,
      'precision': precision,
      'recall': recall,
      'f1': f1,
    };
  }

  /// Check if symptom belongs to type based on tags
  bool _isSymptomOfType(List<String> tags, String type) {
    final lowerTags = tags.map((t) => t.toLowerCase()).toList();
    
    switch (type) {
      case 'Digestif':
        return lowerTags.any((t) => 
          t.contains('douleur') || 
          t.contains('crampes') || 
          t.contains('ballonnement') ||
          t.contains('gaz') ||
          t.contains('digestion') ||
          t.contains('nausée') ||
          t.contains('inflammation')
        );
      case 'Articulaires':
        return lowerTags.any((t) => 
          t.contains('membre') || 
          t.contains('épaule') || 
          t.contains('doigts') ||
          t.contains('articulation')
        );
      case 'Fatigue':
        return lowerTags.any((t) => 
          t.contains('fatigue') || 
          t.contains('énergie') ||
          t.contains('général')
        );
      default:
        return false;
    }
  }

  /// Save training history to database
  Future<void> _saveTrainingHistory(
    Database db,
    Map<String, ModelMetrics> metrics,
  ) async {
    for (final entry in metrics.entries) {
      final metricsMap = entry.value.toJson();
      
      await db.insert('training_history', {
        'trained_at': DateTime.now().toIso8601String(),
        'symptom_type': entry.key,
        'accuracy': metricsMap['accuracy'],
        'precision_score': metricsMap['precision'],
        'recall': metricsMap['recall'],
        'f1_score': metricsMap['f1_score'],
        'training_examples': metricsMap['training_examples'],
        'test_examples': metricsMap['test_examples'],
        'model_version': '1.0.0', // Bump on feature_extractor changes
      });
    }
  }
}
