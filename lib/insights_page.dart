import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'event_model.dart';
import 'database_helper.dart';
import 'app_theme.dart';
import 'themes/app_gradients.dart';
import 'themes/chart_colors.dart';
import 'package:intl/intl.dart';
import 'ml/model_manager.dart';
import 'event_detail_page.dart';
import 'services/training_service.dart';
import 'services/pdf_export_service.dart';
import 'ml/model_status_page.dart';
import 'methodology_page.dart';
import 'widgets/weather_correlation_explanation.dart';
import 'utils/platform_utils.dart';

class ZoneTriggerAnalysis {
  final String zoneName;
  final int symptomCount;
  final Map<String, TriggerScore> foodTriggers;
  final Map<String, TriggerScore> tagTriggers;
  final Map<String, TriggerScore> weatherTriggers;
  final bool hasEnoughData;

  ZoneTriggerAnalysis({
    required this.zoneName,
    required this.symptomCount,
    required this.foodTriggers,
    required this.tagTriggers,
    required this.weatherTriggers,
    required this.hasEnoughData,
  });
}

class TriggerScore {
  final String name;
  final int occurrences; // Times feature appeared with symptom
  final int totalOccurrences; // Total times feature appeared
  final double probability; // P(Symptom|Trigger)
  final double confidence; // Based on sample size

  TriggerScore({
    required this.name,
    required this.occurrences,
    required this.totalOccurrences,
    required this.probability,
    required this.confidence,
  });

  double get score => probability * confidence;
}

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  bool _isLoading = true;

  // Real Data
  List<Map<String, dynamic>> _painData = [];
  List<Map<String, dynamic>> _stoolData = [];
  Map<String, int> _zoneData = {}; // New State
  List<EventModel> _suspectMeals = [];

  // Weather Data
  List<Map<String, dynamic>> _weatherData = [];
  Map<String, Map<String, int>> _weatherSymptomCorrelations = {};
  // Weather correlations by symptom type: {weatherCondition: {symptomType: {total, withSymptom}}}
  Map<String, Map<String, Map<String, int>>> _weatherCorrelationsByType = {};
  // Baseline percentages for each symptom type
  Map<String, double> _symptomBaselinePercentages = {};
  int _totalDaysAnalyzed = 0;

  // Analysis
  Map<String, int> _topSuspects = {};

  // ML Data
  Map<String, List<Map<String, dynamic>>> _correlations = {};
  ModelManager? _modelManager;
  bool _hasModels = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final dbHelper = DatabaseHelper();

    // 1. Chart Data
    final pain = await dbHelper.getPainEvolution(30);
    final stool = await dbHelper.getStoolFrequency(30);
    final zones = await dbHelper.getSymptomZones(30); // New Query

    // 2. Suspect Meals Logic
    // Find the latest high pain event
    final events = await dbHelper.getEvents(); // Get all for analysis logic
    final allEventsModels = events.map((e) => EventModel.fromMap(e)).toList();

    EventModel? lastPain;
    try {
      lastPain = allEventsModels.firstWhere(
        (e) => e.type == EventType.symptom && e.severity >= 5,
      );
    } catch (e) {
      lastPain = null;
    }

    List<EventModel> lastMeals = [];
    if (lastPain != null) {
      final rawMeals = await dbHelper.getLastMeals(
        3,
        beforeDate: lastPain.dateTime,
      );
      lastMeals = rawMeals.map((e) => EventModel.fromMap(e)).toList();
    }

    // 3. Global Pattern Analysis (Top Suspects)
    final suspects = _analyzePatterns(allEventsModels);

    // 4. ML Correlations
    final Map<String, List<Map<String, dynamic>>> correlations = {};

    // Get correlations for common tags - simplified calculation
    final tagsToCheck = [
      'Gras',
      'Gluten',
      'Lactose',
      'Épicé',
      'Alcool',
      'Gaz',
    ];
    
    final severeSymptoms = allEventsModels
        .where((e) => e.type == EventType.symptom && e.severity >= 6)
        .toList();
    
    for (final tag in tagsToCheck) {
      int tagCount = 0;
      int symptomAfterTag = 0;

      final mealsWithTag = allEventsModels
          .where((e) => e.type == EventType.meal && e.tags.contains(tag))
          .toList();

      tagCount = mealsWithTag.length;

      for (final meal in mealsWithTag) {
        try {
          final mealTime = DateTime.parse(meal.dateTime);
          final hasSymptomAfter = severeSymptoms.any((symptom) {
            final symptomTime = DateTime.parse(symptom.dateTime);
            final diff = symptomTime.difference(mealTime);
            // IBD symptoms can appear 2-24 hours after a trigger meal
            return diff.inHours >= 2 && diff.inHours <= 24;
          });

          if (hasSymptomAfter) symptomAfterTag++;
        } catch (e) {
          // Skip invalid dates
        }
      }

      if (tagCount > 0) {
        final correlation = symptomAfterTag / tagCount;
        correlations[tag] = [
          {
            'correlation': correlation,
            'count': tagCount,
            'symptoms': symptomAfterTag,
          }
        ];
      }
    }

    // 5. Try to load ML models
    ModelManager? modelManager;
    bool hasModels = false;
    try {
      modelManager = ModelManager();
      await modelManager.initialize();
      // Check if models are actually loaded (not just fallback)
      hasModels = modelManager.isReady;
    } catch (e) {
      debugPrint('[INSIGHTS] Model loading failed (using fallback): $e');
    }

    // 6. Weather Correlations Analysis
    final weatherData = await _loadWeatherCorrelations(allEventsModels);

    if (mounted) {
      setState(() {
        _painData = pain;
        _stoolData = stool;
        _zoneData = zones; // Set State
        _suspectMeals = lastMeals;
        _topSuspects = suspects;
        _correlations = correlations;
        _modelManager = modelManager;
        _hasModels = hasModels;
        _weatherData = weatherData['timeline'] as List<Map<String, dynamic>>;
        _weatherSymptomCorrelations = weatherData['correlations'] as Map<String, Map<String, int>>;
        _weatherCorrelationsByType = weatherData['correlationsByType'] as Map<String, Map<String, Map<String, int>>>;
        _symptomBaselinePercentages = weatherData['baselinePercentages'] as Map<String, double>;
        _totalDaysAnalyzed = weatherData['totalDays'] as int;
        _isLoading = false;
      });
    }
  }

  Map<String, int> _analyzePatterns(List<EventModel> events) {
    Map<String, int> suspectCounts = {};

    for (var event in events) {
      for (var tag in event.tags) {
        suspectCounts[tag] = (suspectCounts[tag] ?? 0) + 1;
      }
    }

    return suspectCounts;
  }

  Future<Map<String, dynamic>> _loadWeatherCorrelations(List<EventModel> events) async {
    final dbHelper = DatabaseHelper();
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 30));
    
    // Get all events with weather data directly from DB
    final allEventsData = await dbHelper.getEvents();
    
    // Timeline data: temperature vs symptoms per day
    final List<Map<String, dynamic>> timeline = [];
    final Map<String, Map<String, int>> correlations = {
      'Froid (<12°C)': {'total': 0, 'withSymptom': 0},
      'Chaud (>28°C)': {'total': 0, 'withSymptom': 0},
      'Humidité élevée (>75%)': {'total': 0, 'withSymptom': 0},
      'Basse pression (<1000 hPa)': {'total': 0, 'withSymptom': 0},
      'Pluie': {'total': 0, 'withSymptom': 0},
    };
    
    // PHASE 1: Group ALL events by day and collect weather data
    final Map<String, Map<String, dynamic>> dayGroups = {};
    
    for (var eventData in allEventsData) {
      try {
        final dateTime = eventData['dateTime'] as String;
        final eventDate = DateTime.parse(dateTime);
        if (eventDate.isBefore(startDate)) continue;
        
        final dayKey = DateTime(eventDate.year, eventDate.month, eventDate.day).toIso8601String();
        
        if (!dayGroups.containsKey(dayKey)) {
          dayGroups[dayKey] = {
            'date': dayKey,
            'symptoms': 0,
            'temperature': null,
            'humidity': null,
            'pressure': null,
            'weather': null,
          };
        }
        
        // Count ALL symptoms for the day
        final type = eventData['type'] as String;
        final severity = eventData['severity'] as int;
        if (type == 'symptom' && severity >= 3) {  // Lower threshold to capture more symptoms
          dayGroups[dayKey]!['symptoms'] = (dayGroups[dayKey]!['symptoms'] as int) + 1;
        }
        
        // Extract weather data from context_data (only once per day)
        if (dayGroups[dayKey]!['temperature'] == null) {
          final contextDataJson = eventData['context_data'] as String?;
          if (contextDataJson != null && contextDataJson.isNotEmpty) {
            try {
              final contextData = jsonDecode(contextDataJson) as Map<String, dynamic>;
              
              final tempRaw = contextData['temperature'];
              final temp = tempRaw is num 
                  ? tempRaw.toDouble() 
                  : (double.tryParse(tempRaw?.toString() ?? ''));
              dayGroups[dayKey]!['temperature'] = temp;
              
              final humidityRaw = contextData['humidity'];
              final humidity = humidityRaw is num 
                  ? humidityRaw.toDouble() 
                  : (double.tryParse(humidityRaw?.toString() ?? ''));
              dayGroups[dayKey]!['humidity'] = humidity;
              
              final pressureRaw = contextData['pressure'];
              final pressure = pressureRaw is num 
                  ? pressureRaw.toDouble() 
                  : (double.tryParse(pressureRaw?.toString() ?? ''));
              dayGroups[dayKey]!['pressure'] = pressure;
              
              dayGroups[dayKey]!['weather'] = contextData['weather'] ?? '';
            } catch (e) {
              // Skip invalid JSON
            }
          }
        }
      } catch (e) {
        // Skip invalid dates
      }
    }
    
    // PHASE 2: Calculate correlations based on complete daily data
    int totalDaysWithSymptoms = 0;
    int totalSymptoms = 0;
    dayGroups.forEach((dayKey, dayData) {
      final temp = dayData['temperature'] as double?;
      final humidity = dayData['humidity'] as double?;
      final pressure = dayData['pressure'] as double?;
      final weather = dayData['weather'] as String? ?? '';
      final symptomCount = dayData['symptoms'] as int;
      final hasSymptom = symptomCount > 0;
      
      if (hasSymptom) {
        totalDaysWithSymptoms++;
        totalSymptoms += symptomCount;
      }
      
      if (temp != null) {
        if (temp < 12.0) {
          correlations['Froid (<12°C)']!['total'] = correlations['Froid (<12°C)']!['total']! + 1;
          if (hasSymptom) correlations['Froid (<12°C)']!['withSymptom'] = correlations['Froid (<12°C)']!['withSymptom']! + 1;
        }
        if (temp > 28.0) {
          correlations['Chaud (>28°C)']!['total'] = correlations['Chaud (>28°C)']!['total']! + 1;
          if (hasSymptom) correlations['Chaud (>28°C)']!['withSymptom'] = correlations['Chaud (>28°C)']!['withSymptom']! + 1;
        }
      }
      
      if (humidity != null && humidity > 75.0) {
        correlations['Humidité élevée (>75%)']!['total'] = correlations['Humidité élevée (>75%)']!['total']! + 1;
        if (hasSymptom) correlations['Humidité élevée (>75%)']!['withSymptom'] = correlations['Humidité élevée (>75%)']!['withSymptom']! + 1;
      }
      
      if (pressure != null && pressure < 1000.0) {
        correlations['Basse pression (<1000 hPa)']!['total'] = correlations['Basse pression (<1000 hPa)']!['total']! + 1;
        if (hasSymptom) correlations['Basse pression (<1000 hPa)']!['withSymptom'] = correlations['Basse pression (<1000 hPa)']!['withSymptom']! + 1;
      }
      
      final weatherCondition = weather.toLowerCase();
      if (weatherCondition.contains('rain')) {
        correlations['Pluie']!['total'] = correlations['Pluie']!['total']! + 1;
        if (hasSymptom) correlations['Pluie']!['withSymptom'] = correlations['Pluie']!['withSymptom']! + 1;
      }
    });
    
    // Convert to timeline list
    timeline.addAll(dayGroups.values);
    timeline.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    
    debugPrint('🔍 Weather correlations loaded:');
    debugPrint('  Total days analyzed: ${dayGroups.length}');
    debugPrint('  Days with symptoms (severity≥5): $totalDaysWithSymptoms');
    debugPrint('  Total symptoms counted: $totalSymptoms');
    correlations.forEach((condition, data) {
      debugPrint('  $condition: ${data['withSymptom']}/${data['total']} = ${data['total']! > 0 ? (data['withSymptom']! / data['total']! * 100).toStringAsFixed(1) : 0}%');
    });
    debugPrint('Timeline days: ${timeline.length}');
    
    // PHASE 3: Categorize symptoms by type and calculate per-type correlations
    final Map<String, Map<String, Map<String, int>>> correlationsByType = {};
    final symptomTypes = ['Articulaires', 'Fatigue', 'Digestif'];
    
    // Initialize structure for each weather condition and symptom type
    for (final condition in correlations.keys) {
      correlationsByType[condition] = {};
      for (final type in symptomTypes) {
        correlationsByType[condition]![type] = {'total': 0, 'withSymptom': 0};
      }
    }
    
    // First, categorize all symptoms by day and type
    final Map<String, Set<String>> symptomsByDayAndType = {}; // dayKey -> Set of symptom types
    final Map<String, int> symptomCountsByType = {
      'Articulaires': 0,
      'Fatigue': 0,
      'Digestif': 0,
    };
    int totalDaysForBaseline = dayGroups.length;
    
    int symptomsCounted = 0;
    int symptomsFiltered = 0;
    for (var eventData in allEventsData) {
      try {
        final type = eventData['type'] as String;
        if (type != 'symptom') continue;
        
        final severity = eventData['severity'] as int;
        if (severity < 3) {
          symptomsFiltered++;
          continue;
        }
        
        final dateTime = eventData['dateTime'] as String;
        final eventDate = DateTime.parse(dateTime);
        if (eventDate.isBefore(startDate)) continue;
        
        final dayKey = DateTime(eventDate.year, eventDate.month, eventDate.day).toIso8601String();
        if (!dayGroups.containsKey(dayKey)) {
          debugPrint('  [DEBUG] Symptom day $dayKey not in dayGroups');
          continue;
        }
        
        symptomsCounted++;
        
        // Categorize symptom based on title, subtitle, and tags
        String? symptomType;
        final title = (eventData['title'] as String? ?? '').toLowerCase();
        final subtitle = (eventData['subtitle'] as String? ?? '').toLowerCase();
        final zone = (eventData['zone'] as String? ?? '').toLowerCase();
        final tagsRaw = eventData['tags'] as String? ?? '';
        
        // Parse tags: handle both JSON array and CSV format
        List<String> tags = [];
        if (tagsRaw.isNotEmpty) {
          if (tagsRaw.startsWith('[')) {
            // JSON format
            try {
              tags = (jsonDecode(tagsRaw) as List<dynamic>).map((e) => e.toString().toLowerCase()).toList();
            } catch (e) {
              // Fallback to CSV
              tags = tagsRaw.split(',').map((t) => t.trim().toLowerCase()).toList();
            }
          } else {
            // CSV format
            tags = tagsRaw.split(',').map((t) => t.trim().toLowerCase()).toList();
          }
        }
        
        debugPrint('  [DEBUG] Processing symptom: title="$title", zone="$zone", tags=$tags, severity=$severity');
        
        // Articulaires: look for "articulation", "articulaire", "articulations", "genoux", "mains", etc.
        if (title.contains('articulation') || subtitle.contains('articulation') || zone.contains('articulation') ||
            tags.any((t) => t.contains('articulation') || t.contains('genoux') || t.contains('mains') || t.contains('pieds') || t.contains('arthralgie'))) {
          symptomType = 'Articulaires';
        } 
        // Fatigue: look for "fatigue", "épuisement", "énergie"
        else if (title.contains('fatigue') || subtitle.contains('fatigue') || zone.contains('fatigue') ||
                   title.contains('épuisement') || subtitle.contains('épuisement') ||
                   tags.any((t) => t.contains('fatigue') || t.contains('énergie') || t.contains('épuisement'))) {
          symptomType = 'Fatigue';
        } 
        // Digestif: look for digestive symptoms
        else if (title.contains('abdominale') || subtitle.contains('abdominale') ||
                   title.contains('crampe') || subtitle.contains('crampe') ||
                   title.contains('nausée') || subtitle.contains('nausée') ||
                   title.contains('douleur') || subtitle.contains('douleur') ||
                   title.contains('inflammation') || subtitle.contains('inflammation') ||
                   zone.contains('abdomen') || zone.contains('intestin') ||
                   tags.any((t) => t.contains('digestif') || t.contains('abdominale') || t.contains('inflammation') || t.contains('douleur'))) {
          symptomType = 'Digestif';
        } 
        else {
          // Default to Digestif for unclassified symptoms (most common in IBD)
          symptomType = 'Digestif';
        }
        
        debugPrint('  [DEBUG] Categorized as: $symptomType');
        
        symptomCountsByType[symptomType] = (symptomCountsByType[symptomType] ?? 0) + 1;
        
        // Mark this day as having this symptom type
        if (!symptomsByDayAndType.containsKey(dayKey)) {
          symptomsByDayAndType[dayKey] = {};
        }
        symptomsByDayAndType[dayKey]!.add(symptomType);
      } catch (e) {
        debugPrint('  [DEBUG] Error processing symptom: $e');
      }
    }
    
    debugPrint('  [DEBUG] Total symptoms in DB: ${allEventsData.where((e) => e['type'] == 'symptom').length}');
    debugPrint('  [DEBUG] Symptoms filtered (severity<3): $symptomsFiltered');
    debugPrint('  [DEBUG] Symptoms processed: $symptomsCounted');
    
    // Now calculate correlations: for each day with weather condition, check if it had each symptom type
    dayGroups.forEach((dayKey, dayData) {
      final temp = dayData['temperature'] as double?;
      final humidity = dayData['humidity'] as double?;
      final pressure = dayData['pressure'] as double?;
      final weather = dayData['weather'] as String? ?? '';
      
      final symptomsThisDay = symptomsByDayAndType[dayKey] ?? {};
      
      // For each weather condition that applies to this day
      if (temp != null && temp < 12.0) {
        for (final type in symptomTypes) {
          correlationsByType['Froid (<12°C)']![type]!['total'] = 
              (correlationsByType['Froid (<12°C)']![type]!['total']! + 1);
          if (symptomsThisDay.contains(type)) {
            correlationsByType['Froid (<12°C)']![type]!['withSymptom'] = 
                (correlationsByType['Froid (<12°C)']![type]!['withSymptom']! + 1);
          }
        }
      }
      
      if (temp != null && temp > 28.0) {
        for (final type in symptomTypes) {
          correlationsByType['Chaud (>28°C)']![type]!['total'] = 
              (correlationsByType['Chaud (>28°C)']![type]!['total']! + 1);
          if (symptomsThisDay.contains(type)) {
            correlationsByType['Chaud (>28°C)']![type]!['withSymptom'] = 
                (correlationsByType['Chaud (>28°C)']![type]!['withSymptom']! + 1);
          }
        }
      }
      
      if (humidity != null && humidity > 75.0) {
        for (final type in symptomTypes) {
          correlationsByType['Humidité élevée (>75%)']![type]!['total'] = 
              (correlationsByType['Humidité élevée (>75%)']![type]!['total']! + 1);
          if (symptomsThisDay.contains(type)) {
            correlationsByType['Humidité élevée (>75%)']![type]!['withSymptom'] = 
                (correlationsByType['Humidité élevée (>75%)']![type]!['withSymptom']! + 1);
          }
        }
      }
      
      if (pressure != null && pressure < 1000.0) {
        for (final type in symptomTypes) {
          correlationsByType['Basse pression (<1000 hPa)']![type]!['total'] = 
              (correlationsByType['Basse pression (<1000 hPa)']![type]!['total']! + 1);
          if (symptomsThisDay.contains(type)) {
            correlationsByType['Basse pression (<1000 hPa)']![type]!['withSymptom'] = 
                (correlationsByType['Basse pression (<1000 hPa)']![type]!['withSymptom']! + 1);
          }
        }
      }
      
      final weatherCondition = weather.toLowerCase();
      if (weatherCondition.contains('rain')) {
        for (final type in symptomTypes) {
          correlationsByType['Pluie']![type]!['total'] = 
              (correlationsByType['Pluie']![type]!['total']! + 1);
          if (symptomsThisDay.contains(type)) {
            correlationsByType['Pluie']![type]!['withSymptom'] = 
                (correlationsByType['Pluie']![type]!['withSymptom']! + 1);
          }
        }
      }
    });
    
    // Calculate baseline percentages for each symptom type (days with symptom / total days)
    final Map<String, double> baselinePercentages = {};
    final Map<String, int> daysWithSymptomByType = {};
    
    symptomsByDayAndType.forEach((dayKey, types) {
      for (final type in types) {
        daysWithSymptomByType[type] = (daysWithSymptomByType[type] ?? 0) + 1;
      }
    });
    
    for (final type in symptomTypes) {
      final daysWithSymptom = daysWithSymptomByType[type] ?? 0;
      baselinePercentages[type] = totalDaysForBaseline > 0 
          ? (daysWithSymptom / totalDaysForBaseline * 100) 
          : 0.0;
    }
    
    if (kDebugMode) {
      debugPrint('🔍 Symptom type breakdown:');
      symptomCountsByType.forEach((type, count) {
        final daysWithSymptom = daysWithSymptomByType[type] ?? 0;
        debugPrint('  $type: $count symptoms over $daysWithSymptom days (${baselinePercentages[type]?.toStringAsFixed(1)}% baseline)');
      });
      debugPrint('🔍 Correlations by type:');
      correlationsByType.forEach((condition, typeData) {
        debugPrint('  $condition:');
        typeData.forEach((type, data) {
          if ((data['total'] ?? 0) > 0) {
            final percentage = (data['withSymptom']! / data['total']! * 100);
            debugPrint('    $type: ${data['withSymptom']}/${data['total']} = ${percentage.toStringAsFixed(1)}%');
          }
        });
      });
    }
    
    return {
      'timeline': timeline,
      'correlations': correlations,
      'correlationsByType': correlationsByType,
      'baselinePercentages': baselinePercentages,
      'totalDays': totalDaysForBaseline,
    };
  }

  Future<ZoneTriggerAnalysis> _analyzeTriggersForZone(String zoneName) async {
    final dbHelper = DatabaseHelper();
    
    // 1. Get symptoms for this zone
    final symptomsData = await dbHelper.getSymptomsByZone(zoneName, days: 90);
    final symptoms = symptomsData.map((e) => EventModel.fromMap(e)).toList();
    
    if (symptoms.length < 3) {
      return ZoneTriggerAnalysis(
        zoneName: zoneName,
        symptomCount: symptoms.length,
        foodTriggers: {},
        tagTriggers: {},
        weatherTriggers: {},
        hasEnoughData: false,
      );
    }
    
    // 2. For each symptom, find meals 24h before
    final Map<String, int> foodCounts = {};
    final Map<String, int> foodWithSymptomCounts = {};
    final Map<String, int> tagCounts = {};
    final Map<String, int> tagWithSymptomCounts = {};
    final Map<String, int> weatherWithSymptomCounts = {};
    
    // Get all meals for baseline (last 90 days)
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 90));
    final allMealsData = await dbHelper.getMealsInRange(startDate, now);
    final allMeals = allMealsData.map((e) => EventModel.fromMap(e)).toList();
    
    // Count total occurrences of each feature
    for (var meal in allMeals) {
      // Count tags (exclude symptom-like tags)
      final excludedTags = ['Peau', 'Difficile', 'Douleur', 'Crampes', 'Eau', 
                            'Sang', 'Inflammation', 'Général', 'Urgente', 
                            'Maigre', 'Végétal', 'Friture', 'Excitant', 
                            'Hydratation', 'Constipant', 'Rouge', 'Dur', 
                            'Soja', 'Oeuf', 'Plaisir', 'Sulfites'];
      for (var tag in meal.tags) {
        if (tag.isNotEmpty && !excludedTags.contains(tag)) {
          tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
        }
      }
      
      // Count food names
      if (meal.metaData != null && meal.metaData!.isNotEmpty) {
        try {
          final meta = jsonDecode(meal.metaData!);
          if (meta['foods'] is List) {
            for (var food in meta['foods']) {
              if (food is Map && food['name'] != null) {
                final name = food['name'] as String;
                foodCounts[name] = (foodCounts[name] ?? 0) + 1;
              }
            }
          }
        } catch (_) {}
      }
    }
    
    // Analyze each symptom
    for (var symptom in symptoms) {
      final symptomTime = symptom.timestamp;
      final windowStart = symptomTime.subtract(const Duration(hours: 24));
      
      // Find meals in the 24h window
      final mealsData = await dbHelper.getMealsInRange(windowStart, symptomTime);
      final meals = mealsData.map((e) => EventModel.fromMap(e)).toList();
      
      for (var meal in meals) {
        // Count tags associated with symptoms (exclude symptom-like tags)
        final excludedTags = ['Peau', 'Difficile', 'Douleur', 'Crampes', 'Eau', 
                              'Sang', 'Inflammation', 'Général', 'Urgente', 
                              'Maigre', 'Végétal', 'Friture', 'Excitant', 
                              'Hydratation', 'Constipant', 'Rouge', 'Dur', 
                              'Soja', 'Oeuf', 'Plaisir', 'Sulfites'];
        for (var tag in meal.tags) {
          if (tag.isNotEmpty && !excludedTags.contains(tag)) {
            tagWithSymptomCounts[tag] = (tagWithSymptomCounts[tag] ?? 0) + 1;
          }
        }
        
        // Count food names associated with symptoms
        if (meal.metaData != null && meal.metaData!.isNotEmpty) {
          try {
            final meta = jsonDecode(meal.metaData!);
            if (meta['foods'] is List) {
              for (var food in meta['foods']) {
                if (food is Map && food['name'] != null) {
                  final name = food['name'] as String;
                  foodWithSymptomCounts[name] = (foodWithSymptomCounts[name] ?? 0) + 1;
                }
              }
            }
          } catch (_) {}
        }
      }
      
      // Extract weather from context_data (if exists)
      try {
        final contextData = await dbHelper.getContextForEvent(symptom.id!);
        if (contextData != null) {
          // Parse temperature, humidity, pressure (stored as strings)
          final tempRaw = contextData['temperature'];
          final humidityRaw = contextData['humidity'];
          final pressureRaw = contextData['pressure'];
          final weatherCondition = contextData['weather'] ?? '';
          
          // Convert to double with fallback
          final temp = tempRaw is num 
              ? tempRaw.toDouble() 
              : (double.tryParse(tempRaw?.toString() ?? '') ?? 20.0);
          final humidity = humidityRaw is num 
              ? humidityRaw.toDouble() 
              : (double.tryParse(humidityRaw?.toString() ?? '') ?? 60.0);
          final pressure = pressureRaw is num 
              ? pressureRaw.toDouble() 
              : (double.tryParse(pressureRaw?.toString() ?? '') ?? 1013.0);
          
          // Categorize weather conditions
          final List<String> weatherCategories = [];
          
          // Temperature categories
          if (temp < 12.0) {
            weatherCategories.add('Froid (<12°C)');
          } else if (temp > 28.0) {
            weatherCategories.add('Chaud (>28°C)');
          }
          
          // Humidity categories
          if (humidity > 75.0) {
            weatherCategories.add('Humidité élevée (>75%)');
          } else if (humidity < 40.0) {
            weatherCategories.add('Air sec (<40%)');
          }
          
          // Pressure categories
          if (pressure < 1000.0) {
            weatherCategories.add('Basse pression (<1000 hPa)');
          } else if (pressure > 1020.0) {
            weatherCategories.add('Haute pression (>1020 hPa)');
          }
          
          // Weather condition categories
          if (weatherCondition.toLowerCase().contains('rain')) {
            weatherCategories.add('Pluie');
          } else if (weatherCondition.toLowerCase().contains('cloud')) {
            weatherCategories.add('Nuageux');
          }
          
          // Count each weather category
          for (final category in weatherCategories) {
            weatherWithSymptomCounts[category] = 
                (weatherWithSymptomCounts[category] ?? 0) + 1;
          }
        }
      } catch (_) {}
    }
    
    // 3. Calculate probabilities P(Symptom|Feature)
    final foodTriggers = <String, TriggerScore>{};
    final tagTriggers = <String, TriggerScore>{};
    final weatherTriggers = <String, TriggerScore>{};
    
    // Process food triggers
    foodWithSymptomCounts.forEach((food, symptomCount) {
      final totalCount = foodCounts[food] ?? symptomCount;
      if (totalCount >= 3) { // Minimum 3 occurrences
        final probability = symptomCount / totalCount;
        final confidence = min(totalCount / 10.0, 1.0); // Max confidence at 10+ samples
        
        foodTriggers[food] = TriggerScore(
          name: food,
          occurrences: symptomCount,
          totalOccurrences: totalCount,
          probability: probability,
          confidence: confidence,
        );
      }
    });
    
    // Process tag triggers
    tagWithSymptomCounts.forEach((tag, symptomCount) {
      final totalCount = tagCounts[tag] ?? symptomCount;
      if (totalCount >= 3) {  // Minimum 3 occurrences
        final probability = symptomCount / totalCount;
        final confidence = min(totalCount / 10.0, 1.0);
        
        tagTriggers[tag] = TriggerScore(
          name: tag,
          occurrences: symptomCount,
          totalOccurrences: totalCount,
          probability: probability,
          confidence: confidence,
        );
      }
    });
    
    // Process weather triggers
    weatherWithSymptomCounts.forEach((weather, symptomCount) {
      if (symptomCount >= 2) {
        // For weather we don't have a "total" count, so use symptom count as baseline
        final probability = symptomCount / symptoms.length;
        final confidence = min(symptomCount / 5.0, 1.0);
        
        weatherTriggers[weather] = TriggerScore(
          name: weather,
          occurrences: symptomCount,
          totalOccurrences: symptoms.length, // Total symptoms in zone
          probability: probability,
          confidence: confidence,
        );
      }
    });
    
    return ZoneTriggerAnalysis(
      zoneName: zoneName,
      symptomCount: symptoms.length,
      foodTriggers: foodTriggers,
      tagTriggers: tagTriggers,
      weatherTriggers: weatherTriggers,
      hasEnoughData: true,
    );
  }

  Future<void> _showZoneTriggers(String zoneName) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Analyse des déclencheurs...'),
              ],
            ),
          ),
        ),
      ),
    );
    
    // Analyze triggers
    final analysis = await _analyzeTriggersForZone(zoneName);
    
    if (!mounted) return;
    Navigator.pop(context); // Close loading
    
    // Show results
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: analysis.hasEnoughData
                ? _buildTriggerAnalysisContent(analysis, scrollController)
                : _buildInsufficientDataContent(analysis, scrollController),
          );
        },
      ),
    );
  }

  /// Trigger ML model training
  Future<void> _triggerTraining() async {
    final trainingService = TrainingService();
    
    // Show loading dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Analyse statistique en cours...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Check data availability first
      final dataStatus = await trainingService.checkDataAvailability();
      
      if (!dataStatus.hasEnoughData) {
        if (!mounted) return;
        Navigator.pop(context); // Close loading dialog
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Données insuffisantes'),
            content: Text(dataStatus.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // Trigger training
      TrainingResult result;
      
      // Call service (logic handles platform switch internally now)
      result = await trainingService.trainModels();
      
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Show result
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(result.success ? 'Analyse terminée' : 'Erreur'),
          content: Text(result.message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (result.success) {
                  // Reload data to show new predictions
                  setState(() => _isLoading = true);
                  _loadData();
                }
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Erreur'),
          content: Text('Échec de l\'entraînement: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _exportPdf() async {
    if (_weatherCorrelationsByType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune donnée météo à exporter. Veuillez d\'abord charger les analyses.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Génération du PDF...'),
            ],
          ),
        ),
      );

      // Get recent symptoms for the report
      final dbHelper = DatabaseHelper();
      final recentEvents = await dbHelper.getEvents();
      final recentSymptoms = recentEvents
          .map((e) => EventModel.fromMap(e))
          .where((e) => e.type == EventType.symptom && e.severity >= 5)
          .take(20)
          .toList();

      // Generate PDF
      final pdfFile = await PdfExportService.generateInsightsPdf(
        correlationsByType: _weatherCorrelationsByType,
        symptomBaselinePercentages: _symptomBaselinePercentages,
        totalDaysAnalyzed: _totalDaysAnalyzed,
        recentSymptoms: recentSymptoms,
        patientName: null, // Could be fetched from settings if available
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Show success dialog with options
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('PDF généré !'),
          content: Text('Le rapport a été enregistré :\n${pdfFile.path}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await PdfExportService.sharePdf(pdfFile);
              },
              child: const Text('Partager'),
            ),
            if (PlatformUtils.isMobile)
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await PdfExportService.printPdf(pdfFile);
                },
                child: const Text('Imprimer'),
              ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Erreur'),
          content: Text('Échec de la génération du PDF: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildInsufficientDataContent(
    ZoneTriggerAnalysis analysis,
    ScrollController scrollController,
  ) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(24),
      children: [
        // Handle
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: AppColors.painGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.warning, color: Theme.of(context).colorScheme.onPrimary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    analysis.zoneName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Données insuffisantes',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 32),
        
        // Message
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(Icons.info_outline, color: Theme.of(context).colorScheme.secondary, size: 48),
              const SizedBox(height: 16),
              Text(
                'Pas assez de données pour une analyse fiable',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Il faut au moins 3 événements de type "${analysis.zoneName}" pour identifier des déclencheurs.\n\nActuellement : ${analysis.symptomCount} événement(s).',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryStart,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Fermer', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildTriggerAnalysisContent(
    ZoneTriggerAnalysis analysis,
    ScrollController scrollController,
  ) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(24),
      children: [
        // Handle
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: AppColors.painGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.psychology, color: Theme.of(context).colorScheme.onPrimary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    analysis.zoneName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '${analysis.symptomCount} événements analysés',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Exporter le rapport',
              onPressed: () => _exportTriggerReport(analysis),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Food Triggers
        if (analysis.foodTriggers.isNotEmpty) ...[
          _buildTriggerSection(
            title: 'Aliments Suspects',
            icon: Icons.restaurant,
            color: AppColors.mealStart,
            triggers: analysis.foodTriggers,
          ),
          const SizedBox(height: 20),
        ],
        
        // Tag Triggers
        if (analysis.tagTriggers.isNotEmpty) ...[
          _buildTriggerSection(
            title: 'Catégories Alimentaires',
            icon: Icons.label,
            color: AppColors.primaryStart,
            triggers: analysis.tagTriggers,
          ),
          const SizedBox(height: 20),
        ],
        
        // Weather Triggers
        if (analysis.weatherTriggers.isNotEmpty) ...[
          _buildTriggerSection(
            title: 'Conditions Météo',
            icon: Icons.wb_cloudy,
            color: AppColors.checkup,
            triggers: analysis.weatherTriggers,
          ),
          const SizedBox(height: 20),
        ],
        
        // Empty state
        if (analysis.foodTriggers.isEmpty &&
            analysis.tagTriggers.isEmpty &&
            analysis.weatherTriggers.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.check_circle, color: Theme.of(context).colorScheme.tertiary, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Aucun déclencheur significatif identifié',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Les événements de type "${analysis.zoneName}" ne semblent pas corrélés à des aliments ou conditions spécifiques.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        
        // Close button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryStart,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Fermer', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildTriggerSection({
    required String title,
    required IconData icon,
    required Color color,
    required Map<String, TriggerScore> triggers,
  }) {
    if (triggers.isEmpty) {
      return SizedBox.shrink();
    }

    // Sort by score (probability * confidence)
    final sortedTriggers = triggers.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    
    // Filter by score threshold AND limit to 10
    final filteredTriggers = sortedTriggers
      .where((t) => t.score >= 0.15)
      .take(10)
      .toList();
    
    if (filteredTriggers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Données encore limitées pour cette catégorie',
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...filteredTriggers.map((trigger) => _buildTriggerItem(trigger, color)),
        if (sortedTriggers.length > 10)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Affichage des 10 déclencheurs les plus probables',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
            ),
          ),
      ],
    );
  }

  Widget _buildTriggerItem(TriggerScore trigger, Color color) {
    final riskLevel = trigger.probability >= 0.7
        ? 'Élevé'
        : trigger.probability >= 0.4
            ? 'Moyen'
            : 'Faible';
    final riskColor = trigger.probability >= 0.7
        ? Theme.of(context).colorScheme.error
        : trigger.probability >= 0.4
            ? Theme.of(context).colorScheme.secondary
            : const Color(0xFFFBC02D); // Yellow 700
    
    // Reliability badge based on sample size
    final reliability = trigger.totalOccurrences >= 10
        ? 'Fiable'
        : trigger.totalOccurrences >= 5
            ? 'Indicatif'
            : 'Insuffisant';
    final reliabilityColor = trigger.totalOccurrences >= 10
        ? Theme.of(context).colorScheme.primary
        : trigger.totalOccurrences >= 5
            ? Colors.orange
            : Colors.grey;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trigger.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // RÈGLE 1: Corrélation brute (contexte)
                    Text(
                      '${trigger.occurrences} symptômes sur ${trigger.totalOccurrences} occurrences (${(trigger.probability * 100).toStringAsFixed(0)}%)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // RÈGLE 3: Badge de signification (force)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  riskLevel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: riskColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // RÈGLE 4: Badge de fiabilité (taille échantillon)
          Row(
            children: [
              Icon(
                Icons.fact_check_outlined,
                size: 14,
                color: reliabilityColor,
              ),
              const SizedBox(width: 4),
              Text(
                reliability,
                style: TextStyle(
                  fontSize: 11,
                  color: reliabilityColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${trigger.totalOccurrences} échantillons)',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _exportTriggerReport(ZoneTriggerAnalysis analysis) async {
    final buffer = StringBuffer();
    buffer.writeln('=== RAPPORT D\'ANALYSE DES DÉCLENCHEURS ===');
    buffer.writeln('');
    buffer.writeln('Zone: ${analysis.zoneName}');
    buffer.writeln('Nombre d\'événements: ${analysis.symptomCount}');
    buffer.writeln('Date: ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now())}');
    buffer.writeln('');
    
    if (analysis.foodTriggers.isNotEmpty) {
      buffer.writeln('--- ALIMENTS SUSPECTS ---');
      final sorted = analysis.foodTriggers.values.toList()
        ..sort((a, b) => b.score.compareTo(a.score));
      for (var trigger in sorted) {
        buffer.writeln('• ${trigger.name}');
        buffer.writeln('  Occurrences: ${trigger.occurrences}');
        buffer.writeln('  Probabilité: ${(trigger.probability * 100).toStringAsFixed(1)}%');
        buffer.writeln('  Confiance: ${(trigger.confidence * 100).toStringAsFixed(1)}%');
        buffer.writeln('');
      }
    }
    
    if (analysis.tagTriggers.isNotEmpty) {
      buffer.writeln('--- CATÉGORIES ALIMENTAIRES ---');
      final sorted = analysis.tagTriggers.values.toList()
        ..sort((a, b) => b.score.compareTo(a.score));
      for (var trigger in sorted) {
        buffer.writeln('• ${trigger.name}');
        buffer.writeln('  Occurrences: ${trigger.occurrences}');
        buffer.writeln('  Probabilité: ${(trigger.probability * 100).toStringAsFixed(1)}%');
        buffer.writeln('');
      }
    }
    
    if (analysis.weatherTriggers.isNotEmpty) {
      buffer.writeln('--- CONDITIONS MÉTÉO ---');
      final sorted = analysis.weatherTriggers.values.toList()
        ..sort((a, b) => b.score.compareTo(a.score));
      for (var trigger in sorted) {
        buffer.writeln('• ${trigger.name}');
        buffer.writeln('  Occurrences: ${trigger.occurrences}');
        buffer.writeln('  Fréquence: ${(trigger.probability * 100).toStringAsFixed(1)}%');
        buffer.writeln('');
      }
    }
    
    buffer.writeln('---');
    buffer.writeln('Généré par Crohnicles');
    
    // Copy to clipboard
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Rapport copié dans le presse-papier'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        title: Text(
          "Tableau de Bord",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            tooltip: 'Analyses Statistiques',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ModelStatusPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Exporter en PDF',
            onPressed: _isLoading ? null : _exportPdf,
          ),
          IconButton(
            icon: const Icon(Icons.psychology_outlined),
            tooltip: PlatformUtils.isMobile
                ? 'Entraînement (Desktop uniquement)'
                : 'Analyser les corrélations',
            onPressed: _triggerTraining,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir les statistiques',
            onPressed: () {
              setState(() => _isLoading = true);
              _loadData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSuspectsCard(),
                const SizedBox(height: 24),

                // Show latest meal risk if available (New)
                if (_suspectMeals.isNotEmpty) ...[
                   _buildLastRiskAssessmentCard(),
                   const SizedBox(height: 24),
                ],

                // ML Predictions Section
                if (_modelManager != null) ...[
                  _buildMLPredictionsCard(),
                  const SizedBox(height: 24),
                ],

                // Correlations Section
                if (_correlations.isNotEmpty) ...[
                  _buildCorrelationsCard(),
                  const SizedBox(height: 24),
                ],

                // --- PAIN CHART ---
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: AppColors.painGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.painStart.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.multiline_chart,
                            color: Theme.of(context).colorScheme.onPrimary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Courbe de Douleur (30j)",
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                      child: SizedBox(height: 250, child: _buildPainChart()),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // --- ZONES CHART ---
                if (_zoneData.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: AppColors.painGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.painStart.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.pie_chart,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Localisation des Douleurs",
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(height: 220, child: _buildZoneChart()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // --- STOOL CHART ---
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: AppColors.stoolGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.stoolStart.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.bar_chart,
                            color: Theme.of(context).colorScheme.onPrimary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Fréquence du Transit (30j)",
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(height: 200, child: _buildStoolChart()),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // --- WEATHER CORRELATIONS ---
                if (_weatherData.isNotEmpty && _weatherSymptomCorrelations.isNotEmpty) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF42A5F5).withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.wb_cloudy,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Corrélations Météo & Symptômes",
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Weather Timeline Chart
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                        child: SizedBox(height: 250, child: _buildWeatherTimelineChart()),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Stacked Bar Chart - Symptom Types Breakdown (removed basic bar chart - redundant)
                  if (_weatherCorrelationsByType.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(height: 280, child: _buildWeatherStackedBarChart()),
                      ),
                    ),
                  ),
                    const SizedBox(height: 16),
                    
                    // Detailed Explanations per Weather Condition
                    ..._buildWeatherCorrelationExplanations(),
                  ],
                  
                  const SizedBox(height: 24),
                ],

                // --- RECENT SUSPECT MEALS ---
                if (_suspectMeals.isNotEmpty) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Derniers repas avant crise",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.painEnd,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 3,
                        width: 60,
                        decoration: BoxDecoration(
                          gradient: AppColors.mealGradient,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Aliments pris avant la dernière douleur > 5/10",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._suspectMeals
                      .map(
                        (e) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ListTile(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EventDetailPage(event: e),
                                ),
                              );
                            },
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: AppColors.mealGradient.scale(0.4),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.warning_amber_rounded,
                                color: Theme.of(context).colorScheme.onPrimary,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              e.title,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            subtitle: Text(
                              "${e.dateTime.length > 10
                                      ? DateFormat(
                                          'dd/MM HH:mm',
                                        ).format(DateTime.parse(e.dateTime))
                                      : e.dateTime}\n${e.tags.join(', ')}",
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            isThreeLine: true,
                          ),
                        ),
                      )
                      ,
                ] else ...[
                  Text(
                    "Pas de données récentes de crise pour analyser les derniers repas.",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],

                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildLastRiskAssessmentCard() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          // Trigger risk assessment for the last meal
          if (_suspectMeals.isNotEmpty) {
             // We need context, but we don't have it stored historically perfectly.
             // We can pass a dummy context or try to reconstruct.
             // For now, we will show a dialog saying "Context historique non disponible"
             // Or better, just show the detail page.
             Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EventDetailPage(event: _suspectMeals.first),
                ),
              );
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryStart.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.assessment,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Dernière analyse",
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      "Cliquez pour voir les détails du dernier repas",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuspectsCard() {
    if (_topSuspects.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Text(
          "Pas encore assez de données pour détecter des déclencheurs.",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient.scale(0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.analytics_outlined,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Déclencheurs Potentiels",
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      "Tags les plus fréquents dans vos repas",
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: (_topSuspects.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value))) // Tri par fréquence
              .take(15) // Limite à 15 tags les plus fréquents
              .map((e) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryStart.withValues(alpha: 0.15),
                      AppColors.primaryEnd.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primaryStart.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  "${e.key} (${e.value})",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primaryEnd,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPainChart() {
    // Transform SQL data (Date Text, Int Max) to FlSpots
    // X axis: Day index (0 to 30)
    // We map date string to relative day index
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    List<FlSpot> spots = [];

    for (var entry in _painData) {
      // date format from sqlite is YYYY-MM-DD
      final dateParts = (entry['date'] as String).split('-');
      final date = DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
      );
      final diff = date.difference(today).inDays; // e.g. -29 to 0

      // Map to 0..29 range where 29 is today
      final xVal = (30 + diff).toDouble();
      if (xVal >= 0 && xVal <= 30) {
        spots.add(FlSpot(xVal, (entry['max_severity'] as int).toDouble()));
      }
    }

    // Sort spots by x
    spots.sort((a, b) => a.x.compareTo(b.x));

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartWidth = constraints.maxWidth;
        final chartColors = AppChartColors.forBrightness(context);
        final textScaleFactor = MediaQuery.textScalerOf(context).scale(1.0);

        return LineChart(
          LineChartData(
            lineTouchData: LineTouchData(
              enabled: true,
              touchCallback: (event, response) {
                if (event is FlTapUpEvent && response?.lineBarSpots != null) {
                  final spot = response!.lineBarSpots!.first;
                  final dayIndex = spot.x.toInt();
                  final date = today.add(Duration(days: dayIndex - 30));
                  _showEventsForDay(date);
                }
              },
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (touchedSpot) => chartColors.tooltipBackground,
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final dayIndex = spot.x.toInt();
                    final date = today.add(Duration(days: dayIndex - 30));
                    return LineTooltipItem(
                      '${DateFormat('dd/MM').format(date)}\n${spot.y.toInt()}/10',
                      Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: (12 * textScaleFactor).clamp(10.0, 14.0),
                      ),
                    );
                  }).toList();
                },
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: chartWidth < 375 ? 2.0 : 1.0,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: chartColors.gridLine,
                  strokeWidth: 1,
                );
              },
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    // Show date every 5 days
                    final dayIndex = value.toInt();
                    final date = today.add(Duration(days: dayIndex - 30));
                    if (dayIndex % 5 == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          DateFormat('dd/MM').format(date),
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontSize: (10 * textScaleFactor).clamp(8.0, 12.0),
                            color: chartColors.axisLabel,
                          ),
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                  interval: 1,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: chartWidth < 350 ? 25 : 30,
                  getTitlesWidget: (value, meta) => Text(
                    value.toInt().toString(),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontSize: (10 * textScaleFactor).clamp(8.0, 12.0),
                      color: chartColors.axisLabel,
                    ),
                  ),
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: chartColors.axisLine, width: 1),
            ),
            minX: 0,
            maxX: 30,
            minY: 0,
            maxY: 10,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: chartColors.series[0],
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: chartWidth > 400,
                  checkToShowDot: (spot, barData) {
                    return spot.x == 30; // Only show last point
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      chartColors.series[0].withValues(alpha: 0.2),
                      chartColors.series[0].withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildZoneChart() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartWidth = constraints.maxWidth;
        final chartColors = AppChartColors.forBrightness(context);
        final textScaleFactor = MediaQuery.textScalerOf(context).scale(1.0);

        int i = 0;
        List<PieChartSectionData> sections = [];

        _zoneData.forEach((key, value) {
          final isLarge = value > 5;
          final color = chartColors.series[i % chartColors.series.length];

          sections.add(
            PieChartSectionData(
              color: color,
              value: value.toDouble(),
              title: isLarge ? "$key\n$value" : value.toString(),
              radius: chartWidth < 375 ? (isLarge ? 45 : 35) : (isLarge ? 55 : 45),
              titleStyle: TextStyle(
                fontSize: (11 * textScaleFactor).clamp(8.0, 12.0),
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              badgeWidget: isLarge ? null : null,
            ),
          );
          i++;
        });

        return Row(
          children: [
            Expanded(
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: chartWidth < 375 ? 30 : 40,
                  sectionsSpace: 2,
                  startDegreeOffset: 180,
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      if (event is FlTapUpEvent &&
                          pieTouchResponse != null &&
                          pieTouchResponse.touchedSection != null) {
                        final touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                        if (touchedIndex >= 0 && touchedIndex < _zoneData.length) {
                          final zoneName = _zoneData.keys.toList()[touchedIndex];
                          _showZoneTriggers(zoneName);
                        }
                      }
                    },
                  ),
                ),
              ),
            ),
            // Legend
            const SizedBox(width: 24),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _zoneData.keys.toList().asMap().entries.map((e) {
                    final index = e.key;
                    final name = e.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: chartColors.series[index % chartColors.series.length],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: (12 * textScaleFactor).clamp(10.0, 14.0),
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStoolChart() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    List<BarChartGroupData> barGroups = [];

    for (var entry in _stoolData) {
      final dateParts = (entry['date'] as String).split('-');
      final date = DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
      );
      final diff = date.difference(today).inDays; // e.g. -29 to 0
      final xVal = (30 + diff);

      if (xVal >= 0 && xVal <= 30) {
        final count = (entry['count'] as int).toDouble();
        barGroups.add(
          BarChartGroupData(
            x: xVal,
            barRods: [
              BarChartRodData(
                toY: count,
                color: AppColors.stool,
                width: 8,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ), // Rounded Top
              ),
            ],
          ),
        );
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartWidth = constraints.maxWidth;
        final chartColors = AppChartColors.forBrightness(context);
        final textScaleFactor = MediaQuery.textScalerOf(context).scale(1.0);

        return BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: 8, // Max stools to show per day before capping viz
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ), // Too crowded for 30 bars, maybe show none or range
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 20,
                  getTitlesWidget: (value, meta) => Text(
                    value.toInt().toString(),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontSize: (10 * textScaleFactor).clamp(8.0, 12.0),
                      color: chartColors.axisLabel,
                    ),
                  ),
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: chartWidth > 400,
              horizontalInterval: 1.0,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: chartColors.gridLine,
                  strokeWidth: 1,
                );
              },
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: chartColors.axisLine, width: 1),
            ),
            barGroups: barGroups.map((group) {
              return BarChartGroupData(
                x: group.x,
                barRods: group.barRods.map((rod) {
                  return BarChartRodData(
                    toY: rod.toY,
                    color: chartColors.primary,
                    width: chartWidth < 350 ? 10 : 16,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  );
                }).toList(),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildWeatherTimelineChart() {
    if (_weatherData.isEmpty) {
      return const Center(child: Text('Aucune donnée météo disponible'));
    }

    final chartColors = AppChartColors.forBrightness(context);
    
    // Prepare data points
    final List<FlSpot> tempSpots = [];
    final List<FlSpot> symptomSpots = [];
    
    for (int i = 0; i < _weatherData.length; i++) {
      final data = _weatherData[i];
      final temp = data['temperature'] as double?;
      final symptoms = data['symptoms'] as int;
      
      if (temp != null) {
        tempSpots.add(FlSpot(i.toDouble(), temp));
        symptomSpots.add(FlSpot(i.toDouble(), symptoms.toDouble() * 5)); // Scale symptoms for visibility
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: chartColors.gridLine,
                  strokeWidth: 1,
                );
              },
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                axisNameWidget: const Text('Derniers 30 jours', style: TextStyle(fontSize: 11)),
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 5,
                  getTitlesWidget: (value, meta) {
                    if (value.toInt() >= 0 && value.toInt() < _weatherData.length) {
                      final date = DateTime.parse(_weatherData[value.toInt()]['date'] as String);
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${date.day}/${date.month}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    }
                    return const Text('');
                  },
                ),
              ),
              leftTitles: AxisTitles(
                axisNameWidget: const Text('Température (°C)', style: TextStyle(fontSize: 11)),
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      '${value.toInt()}°',
                      style: const TextStyle(fontSize: 10),
                    );
                  },
                ),
              ),
              rightTitles: AxisTitles(
                axisNameWidget: const Text('Symptômes', style: TextStyle(fontSize: 11)),
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) {
                    final symptomCount = (value / 5).toInt();
                    if (symptomCount == 0) return const Text('');
                    return Text(
                      symptomCount.toString(),
                      style: const TextStyle(fontSize: 10),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: chartColors.axisLine, width: 1),
            ),
            lineBarsData: [
              // Temperature line
              LineChartBarData(
                spots: tempSpots,
                isCurved: true,
                color: const Color(0xFF42A5F5),
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: const Color(0xFF42A5F5).withValues(alpha: 0.1),
                ),
              ),
              // Symptoms line
              LineChartBarData(
                spots: symptomSpots,
                isCurved: false,
                color: AppColors.painStart,
                barWidth: 2,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 3,
                      color: AppColors.painStart,
                      strokeWidth: 0,
                    );
                  },
                ),
              ),
            ],
            minY: 0,
            maxY: () {
              if (tempSpots.isEmpty && symptomSpots.isEmpty) return 30.0;
              final maxTemp = tempSpots.isEmpty ? 0.0 : tempSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
              final maxSymptoms = symptomSpots.isEmpty ? 0.0 : symptomSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
              return (maxTemp > maxSymptoms ? maxTemp : maxSymptoms) + 5;
            }(),
          ),
        );
      },
    );
  }

  Widget _buildWeatherStackedBarChart() {
    if (_weatherCorrelationsByType.isEmpty || _totalDaysAnalyzed == 0) {
      return const Center(child: Text('Données insuffisantes pour l\'analyse par type'));
    }

    final chartColors = AppChartColors.forBrightness(context);
    final List<BarChartGroupData> barGroups = [];
    final symptomTypes = ['Articulaires', 'Fatigue', 'Digestif'];
    final typeColors = {
      'Articulaires': const Color(0xFF1E88E5), // Blue
      'Fatigue': const Color(0xFFFF6F00), // Orange
      'Digestif': const Color(0xFFE53935), // Red
    };
    
    int index = 0;
    final List<String> labels = [];
    
    _weatherCorrelationsByType.forEach((condition, typeData) {
      // Create grouped bars (side by side) instead of stacked
      final List<BarChartRodData> rods = [];
      
      for (final type in symptomTypes) {
        final data = typeData[type];
        if (data == null) {
          continue;
        }
        
        final total = data['total'] ?? 0;
        final withSymptom = data['withSymptom'] ?? 0;
        final percentage = total > 0 ? (withSymptom / total * 100) : 0.0;
        
        rods.add(
          BarChartRodData(
            toY: percentage,
            color: typeColors[type]!,
            width: 14,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        );
      }
      
      // Only add bars with data
      if (rods.isNotEmpty) {
        barGroups.add(
          BarChartGroupData(
            x: index,
            barsSpace: 4,
            barRods: rods,
          ),
        );
        labels.add(condition);
        index++;
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            const Text(
              'Fréquence des symptômes par type selon la météo',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            // Legend
            Wrap(
              spacing: 16,
              alignment: WrapAlignment.center,
              children: symptomTypes.map((type) {
                String label;
                switch (type) {
                  case 'Articulaires':
                    label = 'Douleurs articulaires';
                    break;
                  case 'Fatigue':
                    label = 'Fatigue';
                    break;
                  case 'Digestif':
                    label = 'Symptômes digestifs';
                    break;
                  default:
                    label = type;
                }
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: typeColors[type],
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                  ],
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 100,
                  minY: 0,
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 70,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < labels.length) {
                            final label = labels[value.toInt()];
                            // Shorten long labels for better readability
                            String shortLabel = label;
                            if (label == 'Humidité élevée') shortLabel = 'Humidité';
                            if (label == 'Basse pression') shortLabel = 'B. pression';
                            
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Transform.rotate(
                                angle: -0.5,
                                child: Text(
                                  shortLabel,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      axisNameWidget: const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Fréquence (%)', 
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        interval: 20,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}%',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: chartColors.gridLine,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: chartColors.axisLine, width: 1),
                  ),
                  barGroups: barGroups,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildWeatherCorrelationExplanations() {
    final List<Widget> explanations = [];
    final symptomTypes = ['Articulaires', 'Fatigue', 'Digestif'];
    
    _weatherCorrelationsByType.forEach((weatherCondition, typeData) {
      // Check if this weather condition has any significant data
      bool hasData = false;
      for (final type in symptomTypes) {
        final data = typeData[type];
        if (data != null && (data['total'] ?? 0) > 0) {
          hasData = true;
          break;
        }
      }
      
      if (!hasData) return;
      
      // Create expansion tile for this weather condition
      final List<Widget> typeExplanations = [];
      for (final type in symptomTypes) {
        final data = typeData[type];
        if (data == null) continue;
        
        final total = data['total'] ?? 0;
        final withSymptom = data['withSymptom'] ?? 0;
        final baseline = _symptomBaselinePercentages[type] ?? 0.0;
        
        if (total > 0) {
          typeExplanations.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: WeatherCorrelationExplanation(
                weatherCondition: weatherCondition,
                daysWithCondition: total,
                daysWithSymptoms: withSymptom,
                baselinePercentage: baseline,
                symptomType: type,
              ),
            ),
          );
        }
      }
      
      if (typeExplanations.isNotEmpty) {
        explanations.add(
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
              ),
              child: ExpansionTile(
                initiallyExpanded: false,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                childrenPadding: const EdgeInsets.all(16),
                leading: Icon(
                  _getWeatherIcon(weatherCondition),
                  color: _getWeatherColor(weatherCondition),
                  size: 28,
                ),
                title: Text(
                  weatherCondition,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Analyse détaillée par type de symptôme',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                  ),
                ),
                children: typeExplanations,
              ),
            ),
          ),
        );
      }
    });
    
    return explanations;
  }

  IconData _getWeatherIcon(String condition) {
    if (condition.contains('Froid')) return Icons.ac_unit;
    if (condition.contains('Chaud')) return Icons.wb_sunny;
    if (condition.contains('Humidité')) return Icons.water_drop;
    if (condition.contains('pression')) return Icons.compress;
    if (condition.contains('Pluie')) return Icons.umbrella;
    return Icons.wb_cloudy;
  }

  Color _getWeatherColor(String condition) {
    if (condition.contains('Froid')) return const Color(0xFF1E88E5);
    if (condition.contains('Chaud')) return const Color(0xFFFF6F00);
    if (condition.contains('Humidité')) return const Color(0xFF00ACC1);
    if (condition.contains('pression')) return const Color(0xFF5E35B1);
    if (condition.contains('Pluie')) return const Color(0xFF1976D2);
    return const Color(0xFF42A5F5);
  }

  Widget _buildMLPredictionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.psychology,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Évaluation des Risques",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      _hasModels 
                        ? "📊 Modèle statistique personnel" 
                        : "⚡ Analyse en temps réel",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _hasModels ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.help_outline, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MethodologyPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _hasModels
                        ? "Les modèles sont entraînés sur vos données personnelles pour prédire les réactions à vos repas."
                        : "Les prédictions utilisent des corrélations statistiques. Entraînez les modèles après 30+ repas pour des prédictions personnalisées.",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Les prédictions s'affichent automatiquement après chaque repas.",
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCorrelationsCard() {
    // Sort correlations by strength
    final sortedTags = _correlations.entries.toList()
      ..sort((a, b) {
        final aStrength = a.value.isNotEmpty
            ? (a.value[0]['correlation'] as double).abs()
            : 0.0;
        final bStrength = b.value.isNotEmpty
            ? (b.value[0]['correlation'] as double).abs()
            : 0.0;
        return bStrength.compareTo(aStrength);
      });

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppGradients.meal(Theme.of(context).brightness),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.warning_amber,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text("📊", style: TextStyle(fontSize: 18)),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              "Corrélations Statistiques (30j)",
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        "Basé sur vos données récentes uniquement",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...sortedTags.take(5).map((entry) {
              final tag = entry.key;
              final correlationData = entry.value.isNotEmpty
                  ? entry.value[0]
                  : null;

              if (correlationData == null) return const SizedBox.shrink();

              final correlation = (correlationData['correlation'] as double)
                  .abs();
              final significance = correlation > 0.5
                  ? 'Forte'
                  : (correlation > 0.3 ? 'Modérée' : 'Faible');
              final color = correlation > 0.5
                  ? Theme.of(context).colorScheme.error
                  : (correlation > 0.3
                        ? Theme.of(context).colorScheme.secondary
                        : const Color(0xFFFBC02D)); // Yellow 700

              return GestureDetector(
                onTap: () => _showMealsWithTag(tag),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color.withValues(alpha: 0.8), color],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tag,
                          style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "Corrélation $significance",
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                "${(correlationData['symptoms'] as int)}/${(correlationData['count'] as int)}",
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          LinearProgressIndicator(
                            value: correlation,
                            backgroundColor: color.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "${(correlation * 100).toStringAsFixed(0)}%",
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showEventsForDay(DateTime date) async {
    final db = DatabaseHelper();
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    final allEvents = await db.getEvents();
    final eventsForDay = allEvents
        .map((e) => EventModel.fromMap(e))
        .where((e) {
          try {
            final eventDate = DateTime.parse(e.dateTime);
            return eventDate.isAfter(startOfDay) && eventDate.isBefore(endOfDay);
          } catch (e) {
            return false;
          }
        })
        .toList();
    
    if (eventsForDay.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aucun événement le ${DateFormat('dd/MM/yyyy').format(date)}')),
      );
      return;
    }
    
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Événements du ${DateFormat('dd/MM/yyyy', 'fr_FR').format(date)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: eventsForDay.length,
                itemBuilder: (context, index) {
                  final event = eventsForDay[index];
                  final eventTime = DateTime.parse(event.dateTime);
                  
                  IconData icon;
                  Color color;
                  
                  switch (event.type) {
                    case EventType.meal:
                      icon = event.isSnack ? Icons.local_cafe : Icons.restaurant;
                      color = AppColors.mealStart;
                      break;
                    case EventType.symptom:
                      icon = Icons.favorite_border;
                      color = AppColors.painStart;
                      break;
                    case EventType.stool:
                      icon = Icons.analytics_outlined;
                      color = AppColors.stoolStart;
                      break;
                    default:
                      icon = Icons.event_note;
                      color = AppColors.primaryStart;
                  }
                  
                  return ListTile(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EventDetailPage(event: event),
                        ),
                      );
                    },
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.15),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    title: Text(
                      event.title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    subtitle: Text(
                      DateFormat('HH:mm').format(eventTime),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: event.type == EventType.symptom && event.severity > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${event.severity}/10',
                              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          )
                        : null,
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showMealsWithTag(String tag) async {
    final db = DatabaseHelper();
    final allEvents = await db.getEvents();
    final mealsWithTag = allEvents
        .map((e) => EventModel.fromMap(e))
        .where((e) => e.type == EventType.meal && e.tags.contains(tag))
        .toList();
    
    if (mealsWithTag.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aucun repas trouvé avec le tag "$tag"')),
      );
      return;
    }
    
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: AppColors.mealGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tag,
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${mealsWithTag.length} repas',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: mealsWithTag.length,
                  itemBuilder: (context, index) {
                    final meal = mealsWithTag[index];
                    final mealTime = DateTime.parse(meal.dateTime);
                    
                    return ListTile(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EventDetailPage(event: meal),
                          ),
                        );
                      },
                      leading: CircleAvatar(
                        backgroundColor: AppColors.mealStart.withValues(alpha: 0.15),
                        child: Icon(
                          meal.isSnack ? Icons.local_cafe : Icons.restaurant,
                          color: AppColors.mealStart,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        meal.title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      subtitle: Text(
                        DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(mealTime),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
