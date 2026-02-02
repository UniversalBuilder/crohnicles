import 'dart:convert';
import 'dart:io'; 
import 'package:path_provider/path_provider.dart';
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

/// Manages statistical model loading and inference
class ModelManager {
  final Map<String, Map<String, Map<String, double>>> _loadedStats = {};
  bool _isInitialized = false;
  bool _isTrainedModelLoaded = false;

  /// Returns true if using a trained statistical model, false if real-time analysis
  bool get isUsingTrainedModel => _isTrainedModelLoaded;

  /// Load statistical model from documents directory
  Future<void> initialize() async {
    if (_isInitialized) return;

    print('[ModelManager] Initializing...');

    // Load Statistical Model (trained on-device)
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/statistical_model.json');
      
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final json = jsonDecode(jsonString);
        
        if (json['correlations'] != null) {
          // Load new format (v2.0) with confidence
          final correlations = json['correlations'] as Map<String, dynamic>;
          correlations.forEach((symptomKey, featureMap) {
            _loadedStats[symptomKey] = {};
            (featureMap as Map<String, dynamic>).forEach((featureName, data) {
              if (data is Map) {
                _loadedStats[symptomKey]![featureName] = Map<String, double>.from(data);
              }
            });
          });
          
          _isTrainedModelLoaded = true;
          print('[ModelManager] ✓ Loaded trained statistical model (${_loadedStats.length} symptom types)');
        }
      } else {
        _isTrainedModelLoaded = false;
        print('[ModelManager] No trained model found - will use real-time analysis');
      }
    } catch (e) {
      _isTrainedModelLoaded = false;
      print('[ModelManager] Error loading statistical model: $e');
    }

    _isInitialized = true;
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

    // Add food name keywords to features
    _addFoodKeywords(meal, features);

    // Predict for each symptom type
    for (final config in SymptomTaxonomy.models) {
      final symptomType = config.modelKey;
      
      if (_isTrainedModelLoaded && _loadedStats.containsKey(symptomType)) {
        // Use trained statistical model
        predictions.add(_predictWithTrainedModel(symptomType, features));
      } else {
        // Use real-time analysis
        predictions.add(_predictRealTime(symptomType, features));
      }
    }

    return predictions;
  }

  /// Add food name keywords to features for better matching
  void _addFoodKeywords(EventModel meal, Map<String, double> features) {
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
  }

  /// Predict using trained statistical model
  RiskPrediction _predictWithTrainedModel(
    String symptomType,
    Map<String, double> features,
  ) {
    final correlations = _loadedStats[symptomType]!;
    double totalRisk = 0.0;
    double totalWeight = 0.0;
    final factors = <TopFactor>[];

    features.forEach((featureName, featureValue) {
      if (featureValue > 0.0 && correlations.containsKey(featureName)) {
        final corrData = correlations[featureName]!;
        final probability = corrData['probability'] ?? 0.0;
        final confidence = corrData['confidence'] ?? 0.5;
        
        final weight = confidence * featureValue;
        totalRisk += probability * weight;
        totalWeight += weight;

        if (probability > 0.15) {  // Only show significant factors
          factors.add(TopFactor(
            featureName: featureName,
            contribution: probability * weight,
            humanReadable: _formatFeatureName(featureName),
          ));
        }
      }
    });

    final avgRisk = totalWeight > 0 ? (totalRisk / totalWeight).clamp(0.0, 1.0) : 0.3;
    final avgConfidence = totalWeight > 0 ? (totalWeight / features.length).clamp(0.0, 1.0) : 0.7;

    factors.sort((a, b) => b.contribution.compareTo(a.contribution));

    return RiskPrediction(
      symptomType: symptomType,
      riskScore: avgRisk,
      confidence: avgConfidence,
      topFactors: factors.take(5).toList(),
      explanation: _generateExplanation(symptomType, avgRisk, isTrainedModel: true),
      similarMealIds: [],
    );
  }

  /// Real-time prediction when no trained model exists
  RiskPrediction _predictRealTime(
    String symptomType,
    Map<String, double> features,
  ) {
    // Conservative estimation based on general patterns
    double riskScore = 0.25;  // Low baseline
    
    // Known high-risk factors (general medical knowledge)
    if (features['tag_gras'] == 1.0) riskScore += 0.15;
    if (features['tag_gluten'] == 1.0) riskScore += 0.10;
    if (features['tag_lactose'] == 1.0) riskScore += 0.10;
    if (features['is_late_night'] == 1.0) riskScore += 0.08;
    if (features['keyword_soda'] == 1.0 && symptomType == 'bloating') riskScore += 0.20;
    
    riskScore = riskScore.clamp(0.0, 0.7);  // Cap at 70% for non-personalized
    
    return RiskPrediction(
      symptomType: symptomType,
      riskScore: riskScore,
      confidence: 0.3,  // Low confidence - not personalized
      topFactors: [],
      explanation: _generateExplanation(symptomType, riskScore, isTrainedModel: false),
      similarMealIds: [],
    );
  }

  /// Format feature name for display
  String _formatFeatureName(String feature) {
    const Map<String, String> names = {
      'tag_gras': 'Aliments gras',
      'tag_gluten': 'Gluten',
      'tag_lactose': 'Lactose',
      'tag_sucre': 'Sucre',
      'tag_proteine': 'Protéines',
      'keyword_soda': 'Boissons gazeuses',
      'keyword_coffee': 'Café',
      'keyword_milk': 'Produits laitiers',
      'is_late_night': 'Repas tardif',
    };
    return names[feature] ?? feature.replaceAll('tag_', '').replaceAll('_', ' ');
  }

  /// Generate human-readable explanation
  String _generateExplanation(
    String symptomType,
    double riskScore, {
    required bool isTrainedModel,
  }) {
    final symptomName = {
      'pain': 'douleurs abdominales',
      'diarrhea': 'diarrhée',
      'bloating': 'ballonnements',
      'joints': 'douleurs articulaires',
      'systemic': 'symptômes systémiques',
    }[symptomType] ?? symptomType;

    String baseExplanation;
    if (riskScore < 0.3) {
      baseExplanation = 'Risque faible de $symptomName.';
    } else if (riskScore < 0.7) {
      baseExplanation = 'Risque modéré de $symptomName.';
    } else {
      baseExplanation = 'Risque élevé de $symptomName.';
    }

    if (!isTrainedModel) {
      baseExplanation += ' (Estimation générale - entraînez le modèle pour personnaliser)';
    }

    return baseExplanation;
  }

  /// Check if models are ready
  bool get isReady => _isInitialized;

  /// Get loaded symptom types
  List<String> get loadedSymptomTypes => _loadedStats.keys.toList();
}
