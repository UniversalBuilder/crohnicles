import 'dart:convert';
import 'dart:io'; 
import 'package:path_provider/path_provider.dart';
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
  Map<String, Map<String, double>> _statisticalModels = {};
  bool _isInitialized = false;

  /// Load all models from assets
  Future<void> initialize() async {
    if (_isInitialized) return;

    print('[ModelManager] Initializing...');

    // 1. Load ML Models (Desktop trained)
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
        // Models are optional
      }
    }

    // 2. Load Statistical Models (Mobile trained)
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/statistical_model.json');
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final json = jsonDecode(jsonString);
        if (json['correlations'] != null) {
          _statisticalModels = Map<String, Map<String, double>>.from(
            (json['correlations'] as Map).map(
              (key, value) => MapEntry(
                key,
                Map<String, double>.from(value),
              ),
            ),
          );
          print('[ModelManager] ✓ Loaded Statistical Models');
        }
      }
    } catch (e) {
      print('[ModelManager] Error loading stats: $e');
    }

    _isInitialized = true;

    if (_models.isEmpty && _statisticalModels.isEmpty) {
      print(
        '[ModelManager] ℹ No trained models found - using default heuristics',
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

    // If no ML models loaded, try Statistical Models
    if (predictions.isEmpty && _statisticalModels.isNotEmpty) {
      return _predictWithStats(meal, context, features);
    }
    
    // Fallback if nothing else
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

  /// Use Statistical Engine for predictions
  Future<List<RiskPrediction>> _predictWithStats(
    EventModel meal,
    ContextModel context,
    Map<String, double> features,
  ) async {
    final predictions = <RiskPrediction>[];
    
    // Add specific keywords to features for matching
    if (meal.metaData != null && meal.metaData!.isNotEmpty) {
        try {
          final meta = jsonDecode(meal.metaData!);
          if (meta['foods'] is List) {
            for (var food in meta['foods']) {
              if (food is Map && food['name'] != null) {
                final name = (food['name'] as String).toLowerCase();
                if (name.contains('soda') || name.contains('coca')) features['keyword_soda'] = 1.0;
                if (name.contains('café')) features['keyword_coffee'] = 1.0;
                if (name.contains('lait')) features['keyword_milk'] = 1.0;
                if (name.contains('pain')) features['keyword_bread'] = 1.0;
              }
            }
          }
        } catch (_) {}
    }

    for (final symptom in _statisticalModels.keys) {
      final correlations = _statisticalModels[symptom]!;
      double totalRisk = 0.0;
      final explainedFactors = <TopFactor>[];
      
      // Calculate risk based on present features
      features.forEach((key, value) {
        if (value > 0 && correlations.containsKey(key)) {
          final probability = correlations[key]!;
          // Only count significant risks
          if (probability > 0.1) {
            totalRisk += probability * 0.5; // Scale down individual contributions
            
            // Add to explanation
            explainedFactors.add(TopFactor(
              featureName: key, 
              contribution: probability, 
              humanReadable: '${_humanReadableFeature(key)} (${(probability * 100).toStringAsFixed(0)}%)'
            ));
          }
        }
      });
      
      // Cap risk at 0.95
      totalRisk = totalRisk.clamp(0.0, 0.95);
      
      // Sort factors
      explainedFactors.sort((a, b) => b.contribution.compareTo(a.contribution));

      // Determine explanation text
      String explanation = "Risque faible basé sur vos statistiques.";
      if (totalRisk > 0.6) {
         explanation = "Risque élevé basé sur vos historiques précédents.";
      } else if (totalRisk > 0.3) {
         explanation = "Risque modéré détecté.";
      }

      predictions.add(RiskPrediction(
        symptomType: symptom, 
        riskScore: totalRisk, 
        confidence: 0.8, // Stats are usually reliable if they exist
        topFactors: explainedFactors.take(3).toList(), 
        explanation: explanation, 
        similarMealIds: []
      ));
    }
    
    // If stats are empty for some reason, fallback
    if (predictions.isEmpty) {
        return _fallbackPredictions(meal, context);
    }
    
    return predictions;
  }
  
  String _humanReadableFeature(String key) {
    switch (key) {
      case 'tag_gluten': return 'Gluten';
      case 'tag_lactose': return 'Lactose';
      case 'tag_gras': return 'Aliments gras';
      case 'tag_sucre': return 'Sucre';
      case 'keyword_soda': return 'Soda/Boisson gazeuse';
      case 'keyword_coffee': return 'Café';
      case 'keyword_milk': return 'Lait';
      case 'is_late_night': return 'Repas tardif';
      default: return key.replaceAll('tag_', '').replaceAll('_', ' ');
    }
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

      // Check food names in metadata for specific triggers (Soda, etc.)
      if (meal.metaData != null && meal.metaData!.isNotEmpty) {
        try {
          final meta = jsonDecode(meal.metaData!);
          if (meta['foods'] is List) {
            for (var food in meta['foods']) {
              if (food is Map && food['name'] != null) {
                final name = (food['name'] as String).toLowerCase();

                // Bloating specific triggers
                if (config.modelKey == 'bloating') {
                  if (name.contains('soda') ||
                      name.contains('coca') ||
                      name.contains('pepsi') ||
                      name.contains('gazeu') ||
                      name.contains('limonade')) {
                    riskScore += 0.4; // High impact on bloating
                  }
                  if (name.contains('haricot') || name.contains('chou')) {
                    riskScore += 0.3;
                  }
                }

                // Generic triggers based on name
                if (name.contains('frit') ||
                    name.contains('mcdo') ||
                    name.contains('kebab')) {
                  riskScore += 0.2;
                }
              }
            }
          }
        } catch (e) {
          // Ignore parsing errors
        }
      }

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
