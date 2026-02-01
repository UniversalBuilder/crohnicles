import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../database_helper.dart';
import '../event_model.dart';
import '../ml/feature_extractor.dart';
import '../services/training_service.dart';

/// Calculates probability of symptoms based on historical correlations
/// Replaces Python training on mobile devices
class StatisticalEngine {
  static final StatisticalEngine _instance = StatisticalEngine._internal();
  factory StatisticalEngine() => _instance;
  StatisticalEngine._internal();

  final DatabaseHelper _db = DatabaseHelper();
  
  /// Trains the statistical model and saves it to JSON
  Future<TrainingResult> train() async {
    try {
      print('[StatisticalEngine] Starting correlation analysis...');
      
      // 1. Fetch data
       // We analyze 90 days of history
      final now = DateTime.now();
      final startDate = now.subtract(const Duration(days: 90));
      
      final dbInstance = await _db.database;
      
      // Get all meals
      final mealsData = await dbInstance.query(
        'events',
        where: "type = ? AND dateTime >= ?",
        whereArgs: ['meal', startDate.toIso8601String()],
      );
      final meals = mealsData.map((e) => EventModel.fromMap(e)).toList();
      
      // Get all symptoms
      final symptomsData = await dbInstance.query(
        'events',
        where: "type = ? AND dateTime >= ?",
        whereArgs: ['symptom', startDate.toIso8601String()],
      );
      final symptoms = symptomsData.map((e) => EventModel.fromMap(e)).toList();

      // Get all stools
      final stoolsData = await dbInstance.query(
        'events',
        where: "type = ? AND dateTime >= ?",
        whereArgs: ['stool', startDate.toIso8601String()],
      );
      final stools = stoolsData.map((e) => EventModel.fromMap(e)).toList();

      if (meals.isEmpty) {
        return TrainingResult(
          success: false,
          message: "Pas assez de données pour l'analyse (0 repas trouvés).",
        );
      }

      // 2. Compute Correlations (P(Symptom | Feature))
      
      // Initialize counters
      // Map<FeatureName, Count>
      final featureCounts = <String, int>{};
      
      // Map<SymptomType, Map<FeatureName, Count>>
      final symptomFeatureCounts = <String, Map<String, int>>{
        'pain': {},
        'bloating': {},
        'diarrhea': {},
        // Add others if needed
      };

      // Configuration
      const windowHours = 24; // Look ahead window

      // Iterate through meals to count features
      for (var meal in meals) {
        final mealTime = DateTime.parse(meal.dateTime);
        
        // Extract features (using same logic as ML to be consistent)
        // We only care about categorical features (tags, time, context) for this simple engine
        final features = FeatureExtractor.extractMealFeatures(meal, null, null, 0);
        
        // Filter active features (value == 1.0) and significant numeric ones
        final activeFeatures = <String>[];
        
        features.forEach((key, value) {
          if (value == 1.0) {
            activeFeatures.add(key);
          }
        });
        
        // Add special "food_name" features from metadata
        _extractFoodKeywords(meal, activeFeatures);

        // Update total counts for these features
        for (var feature in activeFeatures) {
          featureCounts[feature] = (featureCounts[feature] ?? 0) + 1;
        }

        // Check for subsequent symptoms and stools
        final subsequentEvents = [...symptoms, ...stools].where((s) {
          final sTime = DateTime.parse(s.dateTime);
          final diff = sTime.difference(mealTime).inHours;
          return diff > 0 && diff <= windowHours;
        }).toList();

        // Update symptom counts
        for (var s in subsequentEvents) {
            // Determine symptom type
            String? symptomType;
            
            if (s.type == EventType.symptom) {
              if (s.tags.contains('Douleur abdominale') || s.tags.contains('pain')) symptomType = 'pain';
              else if (s.tags.contains('Ballonnement') || s.tags.contains('bloating')) symptomType = 'bloating';
              else if (s.tags.contains('Diarrhée') || s.tags.contains('diarrhea')) symptomType = 'diarrhea';
            } else if (s.type == EventType.stool) {
               // Consider Bristol Type 6 & 7 or Urgent as Diarrhea risk
               if (s.title.contains('Type 6') || s.title.contains('Type 7') || s.isUrgent) {
                  symptomType = 'diarrhea';
               }
            }
            
            if (symptomType != null) {
               for (var feature in activeFeatures) {
                 final currentMap = symptomFeatureCounts[symptomType]!;
                 currentMap[feature] = (currentMap[feature] ?? 0) + 1;
               }
            }
        }
      }

      // 3. Compute Probabilities & Confidence Scores
      // Score = (P(S|F) * ConfidenceFactor)
      // where ConfidenceFactor grows with sample size
      
      int totalCorrelations = 0;
      final statsWithConfidence = <String, Map<String, Map<String, double>>>{};
      
      for (var symptom in symptomFeatureCounts.keys) {
        statsWithConfidence[symptom] = {};
        final sCounts = symptomFeatureCounts[symptom]!;
        
        sCounts.forEach((feature, count) {
          final totalOccurrences = featureCounts[feature] ?? 1;
          
          if (totalOccurrences < 3) return; // Ignore very rare correlations
          
          final probability = count / totalOccurrences;
          
          // Calculate confidence based on sample size (like zone trigger analysis)
          // Confidence grows with sample size, maxing at 1.0 when N >= 10
          final confidence = (totalOccurrences / 10.0).clamp(0.0, 1.0);
          
          statsWithConfidence[symptom]![feature] = {
            'probability': double.parse(probability.toStringAsFixed(2)),
            'confidence': double.parse(confidence.toStringAsFixed(2)),
            'sample_size': totalOccurrences.toDouble(),
          };
          
          totalCorrelations++;
        });
      }

      // 4. Save to JSON
      await _saveStats(statsWithConfidence);

      // Prepare detailed message showing all analyzed data
      final totalEvents = meals.length + symptoms.length + stools.length;
      final message = "Analyse statistique terminée.\n\n"
          "📊 Données analysées :\n"
          "• ${meals.length} repas\n"
          "• ${symptoms.length} symptômes\n"
          "• ${stools.length} selles\n"
          "Total : $totalEvents événements\n\n"
          "🔗 Corrélations identifiées : $totalCorrelations";

      return TrainingResult(
        success: true,
        message: message,
        modelsCount: statsWithConfidence.length,
        correlationCount: totalCorrelations,
      );

    } catch (e, stack) {
      print('[StatisticalEngine] Error: $e');
      print(stack);
      return TrainingResult(
        success: false,
        message: "Erreur lors de l'analyse: $e",
      );
    }
  }

  void _extractFoodKeywords(EventModel meal, List<String> activeFeatures) {
    if (meal.metaData != null && meal.metaData!.isNotEmpty) {
        try {
          final meta = jsonDecode(meal.metaData!);
          if (meta['foods'] is List) {
            for (var food in meta['foods']) {
              if (food is Map && food['name'] != null) {
                final name = (food['name'] as String).toLowerCase();
                
                // Add specific keywords as pseudo-features
                if (name.contains('soda') || name.contains('coca')) activeFeatures.add('keyword_soda');
                if (name.contains('café')) activeFeatures.add('keyword_coffee');
                if (name.contains('lait')) activeFeatures.add('keyword_milk');
                if (name.contains('pain')) activeFeatures.add('keyword_bread');
              }
            }
          }
        } catch (_) {}
    }
  }
  
  Future<void> _saveStats(Map<String, Map<String, Map<String, double>>> stats) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/statistical_model.json');
    
    // Add metadata
    final output = {
      'last_updated': DateTime.now().toIso8601String(),
      'version': '2.0',  // Version 2.0 with confidence scores
      'correlations': stats,
    };
    
    await file.writeAsString(jsonEncode(output));
    print('[StatisticalEngine] Saved stats to ${file.path}');
  }
}
