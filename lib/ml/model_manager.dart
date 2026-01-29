import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../database_helper.dart';
import '../event_model.dart';
import '../models/context_model.dart';
import '../symptom_taxonomy.dart';
import 'feature_extractor.dart';

/// Risk prediction result for a meal
class RiskPrediction {
  final String symptomType;
  final double riskScore; // 0.0 to 1.0
  final double confidence; // Model confidence in prediction
  final List<TopFactor> topFactors;
  final String explanation;
  final List<int> similarMealIds;

  RiskPrediction({
    required this.symptomType,
    required this.riskScore,
    required this.confidence,
    required this.topFactors,
    required this.explanation,
    required this.similarMealIds,
  });

  String get riskLevel {
    if (riskScore < 0.3) return 'low';
    if (riskScore < 0.7) return 'medium';
    return 'high';
  }

  String get riskEmoji {
    if (riskScore < 0.3) return '🟢';
    if (riskScore < 0.7) return '🟡';
    return '🔴';
  }
}

/// Top contributing factor to risk prediction
class TopFactor {
  final String featureName;
  final double contribution; // Positive = increases risk
  final String humanReadable;

  TopFactor({
    required this.featureName,
    required this.contribution,
    required this.humanReadable,
  });
}

/// Decision tree node for on-device inference
class TreeNode {
  final bool isLeaf;
  final String? feature;
  final double? threshold;
  final TreeNode? left;
  final TreeNode? right;
  final int? value; // Leaf prediction (0 or 1)
  final double? probability; // Leaf probability

  TreeNode({
    required this.isLeaf,
    this.feature,
    this.threshold,
    this.left,
    this.right,
    this.value,
    this.probability,
  });

  factory TreeNode.fromJson(Map<String, dynamic> json) {
    if (json['is_leaf'] == true) {
      return TreeNode(
        isLeaf: true,
        value: json['value'],
        probability: json['probability'],
      );
    } else {
      return TreeNode(
        isLeaf: false,
        feature: json['feature'],
        threshold: json['threshold'],
        left: TreeNode.fromJson(json['left']),
        right: TreeNode.fromJson(json['right']),
      );
    }
  }

  /// Traverse tree to make prediction
  double predict(Map<String, double> features) {
    if (isLeaf) {
      return probability ?? 0.0;
    }

    final featureValue = features[feature] ?? 0.0;
    if (featureValue <= threshold!) {
      return left!.predict(features);
    } else {
      return right!.predict(features);
    }
  }

  /// Get decision path through tree (for explainability)
  List<String> getDecisionPath(Map<String, double> features) {
    if (isLeaf) {
      return ['Leaf: ${(probability! * 100).toStringAsFixed(1)}% risk'];
    }

    final featureValue = features[feature] ?? 0.0;
    final decision = featureValue <= threshold! ? 'left' : 'right';

    final humanFeature = _humanizeFeature(feature!);
    final path = [
      '$humanFeature ${decision == "left" ? "≤" : ">"} ${threshold!.toStringAsFixed(2)}',
    ];

    if (decision == 'left') {
      path.addAll(left!.getDecisionPath(features));
    } else {
      path.addAll(right!.getDecisionPath(features));
    }

    return path;
  }

  String _humanizeFeature(String feature) {
    // Convert feature names to human-readable strings
    const Map<String, String> humanNames = {
      'tag_legume': 'Légumes',
      'tag_proteine': 'Protéines',
      'tag_gras': 'Aliments gras',
      'tag_gluten': 'Gluten',
      'tag_produit_laitier': 'Produits laitiers',
      'fat_g': 'Lipides (g)',
      'protein_g': 'Protéines (g)',
      'carb_g': 'Glucides (g)',
      'fiber_g': 'Fibres (g)',
      'hour_of_day': 'Heure du repas',
      'is_late_night': 'Repas tardif',
      'weather_rainy': 'Temps pluvieux',
      'pressure_dropping': 'Chute de pression',
    };
    return humanNames[feature] ?? feature;
  }
}

/// Model metadata loaded from JSON
class ModelMetadata {
  final String symptomType;
  final List<String> featureNames;
  final TreeNode tree;
  final Map<String, double> metrics;
  final DateTime trainingDate;

  ModelMetadata({
    required this.symptomType,
    required this.featureNames,
    required this.tree,
    required this.metrics,
    required this.trainingDate,
  });

  factory ModelMetadata.fromJson(Map<String, dynamic> json) {
    return ModelMetadata(
      symptomType: json['symptom_type'],
      featureNames: List<String>.from(json['feature_names']),
      tree: TreeNode.fromJson(json['tree_structure']),
      metrics: Map<String, double>.from(json['metrics']),
      trainingDate: DateTime.parse(json['training_date']),
    );
  }
}

/// Manages ML model loading and inference
class ModelManager {
  final DatabaseHelper _db = DatabaseHelper();

  final Map<String, ModelMetadata> _models = {};
  bool _isInitialized = false;

  /// Load all models from assets
  Future<void> initialize() async {
    if (_isInitialized) return;

    print('[ModelManager] Initializing...');

    // Load all available models from symptom taxonomy
    for (final config in SymptomTaxonomy.models) {
      try {
        final jsonString = await rootBundle.loadString(
          'assets/models/${config.modelKey}_predictor.json',
        );
        final json = jsonDecode(jsonString);
        _models[config.modelKey] = ModelMetadata.fromJson(json);

        print(
          '[ModelManager] ✓ Loaded ${config.modelKey} model (trained: ${_models[config.modelKey]!.trainingDate})',
        );
      } catch (e) {
        // Models are optional - system will use correlation-based fallback
        // This is expected on first launch or if models haven't been trained yet
      }
    }

    _isInitialized = true;

    if (_models.isEmpty) {
      print(
        '[ModelManager] ℹ No trained models found - using correlation-based predictions',
      );
    } else {
      print(
        '[ModelManager] ✓ Initialization complete (${_models.length} models loaded)',
      );
    }
  }

  /// Predict risk for all symptom types given a meal event
  Future<List<RiskPrediction>> predictAllSymptoms(
    EventModel meal,
    ContextModel context,
  ) async {
    await initialize();

    final predictions = <RiskPrediction>[];

    // Extract features from meal
    final features = FeatureExtractor.extractMealFeatures(
      meal,
      context,
      null, // lastMealTime - could be enhanced
      3, // mealsToday - could be enhanced
    );

    for (final symptomType in _models.keys) {
      try {
        final prediction = await _predictSingle(symptomType, features, meal);
        predictions.add(prediction);
      } catch (e) {
        print('[ModelManager] Error predicting $symptomType: $e');
      }
    }

    // If no models loaded, use fallback correlation-based predictions
    if (predictions.isEmpty) {
      return _fallbackPredictions(meal, context);
    }

    return predictions;
  }

  /// Predict risk for a single symptom type
  Future<RiskPrediction> _predictSingle(
    String symptomType,
    Map<String, double> features,
    EventModel meal,
  ) async {
    final model = _models[symptomType]!;

    // Get prediction from decision tree
    final riskScore = model.tree.predict(features);
    final confidence = model.metrics['f1'] ?? 0.7; // Use F1 as confidence proxy

    // Get decision path for explanation
    final decisionPath = model.tree.getDecisionPath(features);
    final explanation = _generateExplanation(
      symptomType,
      riskScore,
      decisionPath,
    );

    // Extract top contributing factors
    final topFactors = await _extractTopFactors(features, model, riskScore);

    // Find similar past meals
    final similarMealIds = await _findSimilarMeals(meal);

    return RiskPrediction(
      symptomType: symptomType,
      riskScore: riskScore,
      confidence: confidence,
      topFactors: topFactors,
      explanation: explanation,
      similarMealIds: similarMealIds,
    );
  }

  /// Extract top contributing factors from feature importance
  Future<List<TopFactor>> _extractTopFactors(
    Map<String, double> features,
    ModelMetadata model,
    double riskScore,
  ) async {
    // For a real implementation, we'd need feature importance from training
    // For now, we'll use a heuristic based on feature values and known correlations

    final factors = <TopFactor>[];

    // High-risk tags
    if (features['tag_gras'] == 1.0) {
      factors.add(
        TopFactor(
          featureName: 'tag_gras',
          contribution: 0.15,
          humanReadable: 'Aliments riches en graisses',
        ),
      );
    }

    if (features['tag_gluten'] == 1.0) {
      factors.add(
        TopFactor(
          featureName: 'tag_gluten',
          contribution: 0.12,
          humanReadable: 'Présence de gluten',
        ),
      );
    }

    if (features['tag_produit_laitier'] == 1.0) {
      factors.add(
        TopFactor(
          featureName: 'tag_produit_laitier',
          contribution: 0.10,
          humanReadable: 'Produits laitiers',
        ),
      );
    }

    // Late night meals
    if (features['is_late_night'] == 1.0) {
      factors.add(
        TopFactor(
          featureName: 'is_late_night',
          contribution: 0.08,
          humanReadable: 'Repas tardif (après 22h)',
        ),
      );
    }

    // High fat content
    final fatGrams = features['fat_g'] ?? 0.0;
    if (fatGrams > 25) {
      factors.add(
        TopFactor(
          featureName: 'fat_g',
          contribution: 0.09,
          humanReadable:
              'Taux élevé de lipides (${fatGrams.toStringAsFixed(0)}g)',
        ),
      );
    }

    // Weather factors
    if (features['is_pressure_dropping'] == 1.0) {
      factors.add(
        TopFactor(
          featureName: 'is_pressure_dropping',
          contribution: 0.06,
          humanReadable: 'Baisse de pression atmosphérique',
        ),
      );
    }

    // Sort by contribution and take top 5
    factors.sort((a, b) => b.contribution.compareTo(a.contribution));
    return factors.take(5).toList();
  }

  /// Generate human-readable explanation
  String _generateExplanation(
    String symptomType,
    double riskScore,
    List<String> decisionPath,
  ) {
    final symptomName =
        {
          'pain': 'douleurs abdominales',
          'diarrhea': 'diarrhée',
          'bloating': 'ballonnements',
        }[symptomType] ??
        symptomType;

    if (riskScore < 0.3) {
      return 'Risque faible de $symptomName. Ce repas présente peu de facteurs déclencheurs habituels.';
    } else if (riskScore < 0.7) {
      return 'Risque modéré de $symptomName. Surveillez l\'apparition de symptômes dans les 4-8 heures.';
    } else {
      return 'Risque élevé de $symptomName. Ce repas contient plusieurs facteurs déclencheurs identifiés.';
    }
  }

  /// Find similar past meals for comparison
  Future<List<int>> _findSimilarMeals(EventModel meal) async {
    try {
      final tagsString = meal.tags.join(',');
      final similarMeals = await _db.getSimilarMeals(
        tagsString,
        meal.metaData ?? '',
        limit: 5,
      );
      return similarMeals.map((m) => m['id'] as int).toList();
    } catch (e) {
      print('[ModelManager] Error finding similar meals: $e');
      return [];
    }
  }

  /// Fallback predictions using correlation-based heuristics
  Future<List<RiskPrediction>> _fallbackPredictions(
    EventModel meal,
    ContextModel context,
  ) async {
    final predictions = <RiskPrediction>[];

    // Use correlation-based fallback for all defined symptom types
    for (final config in SymptomTaxonomy.models) {
      // Simple heuristic based on known trigger tags
      double riskScore = 0.3; // Base risk

      // Use case-insensitive tag matching
      final tagsLower = meal.tags.map((t) => t.toLowerCase()).toList();

      if (tagsLower.contains('gras')) riskScore += 0.2;
      if (tagsLower.contains('gluten')) riskScore += 0.15;
      if (tagsLower.contains('lactose')) riskScore += 0.15;
      if (tagsLower.contains('épicé')) riskScore += 0.1;
      if (tagsLower.contains('alcool')) riskScore += 0.15;
      if (tagsLower.contains('gaz')) riskScore += 0.1;

      riskScore = riskScore.clamp(0.0, 1.0);

      predictions.add(
        RiskPrediction(
          symptomType: config.modelKey,
          riskScore: riskScore,
          confidence: 0.5, // Lower confidence for correlation-based fallback
          topFactors: [],
          explanation:
              'Estimation basée sur des corrélations simples (modèle ML non entraîné)',
          similarMealIds: [],
        ),
      );
    }

    return predictions;
  }

  /// Get model performance metrics
  Map<String, Map<String, double>> getModelMetrics() {
    final metrics = <String, Map<String, double>>{};
    for (final entry in _models.entries) {
      metrics[entry.key] = entry.value.metrics;
    }
    return metrics;
  }

  /// Check if models are loaded
  bool get isReady => _isInitialized && _models.isNotEmpty;

  /// Get loaded symptom types
  List<String> get loadedModels => _models.keys.toList();
}
