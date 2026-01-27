import 'dart:convert';
import 'dart:math';
import '../event_model.dart';
import '../models/context_model.dart';

/// Extracts ML features from events for decision tree models
class FeatureExtractor {
  /// Extract feature vector from a meal event
  /// Returns Map with 60+ features for ML model input
  static Map<String, double> extractMealFeatures(
    EventModel meal,
    ContextModel? context,
    DateTime? lastMealTime,
    int mealsToday,
  ) {
    final features = <String, double>{};
    final mealTime = DateTime.parse(meal.dateTime);

    // === MEAL TAG FEATURES (One-hot encoded) ===
    final tags = meal.tags.map((t) => t.toLowerCase()).toList();
    features['tag_feculent'] = tags.contains('féculent') ? 1.0 : 0.0;
    features['tag_proteine'] = tags.contains('protéine') || tags.contains('viande') ? 1.0 : 0.0;
    features['tag_legume'] = tags.contains('légume') ? 1.0 : 0.0;
    features['tag_produit_laitier'] = tags.contains('produit laitier') || tags.contains('fromage') ? 1.0 : 0.0;
    features['tag_fruit'] = tags.contains('fruit') ? 1.0 : 0.0;
    features['tag_epices'] = tags.contains('épices') || tags.contains('épicé') ? 1.0 : 0.0;
    features['tag_gras'] = tags.contains('gras') ? 1.0 : 0.0;
    features['tag_sucre'] = tags.contains('sucré') || tags.contains('sucre') ? 1.0 : 0.0;
    features['tag_fermente'] = tags.contains('fermenté') ? 1.0 : 0.0;
    features['tag_gluten'] = tags.contains('gluten') ? 1.0 : 0.0;
    features['tag_alcool'] = tags.contains('alcool') ? 1.0 : 0.0;

    // === NUTRITION FEATURES ===
    final foods = _extractFoodsFromMetadata(meal.metaData);
    final nutrition = _aggregateNutrition(foods);
    
    features['protein_g'] = nutrition['proteins'] ?? 0.0;
    features['fat_g'] = nutrition['fats'] ?? 0.0;
    features['carb_g'] = nutrition['carbs'] ?? 0.0;
    features['fiber_g'] = nutrition['fiber'] ?? 0.0;
    features['sugar_g'] = nutrition['sugars'] ?? 0.0;
    features['energy_kcal'] = nutrition['energy'] ?? 0.0;

    // Macro percentages (of total calories)
    final totalKcal = features['energy_kcal']!;
    if (totalKcal > 0) {
      features['protein_pct'] = (features['protein_g']! * 4) / totalKcal * 100;
      features['fat_pct'] = (features['fat_g']! * 9) / totalKcal * 100;
      features['carb_pct'] = (features['carb_g']! * 4) / totalKcal * 100;
    } else {
      features['protein_pct'] = 0.0;
      features['fat_pct'] = 0.0;
      features['carb_pct'] = 0.0;
    }

    // === PROCESSING LEVEL ===
    final avgNovaGroup = _getAverageNovaGroup(foods);
    features['nova_group'] = avgNovaGroup;
    features['is_processed'] = avgNovaGroup >= 3 ? 1.0 : 0.0;

    // === TIMING FEATURES ===
    features['hour_of_day'] = mealTime.hour.toDouble();
    features['day_of_week'] = mealTime.weekday.toDouble();
    features['is_weekend'] = (mealTime.weekday == DateTime.saturday || 
                              mealTime.weekday == DateTime.sunday) ? 1.0 : 0.0;
    
    // Meal type (breakfast, lunch, dinner, snack)
    features['is_breakfast'] = _isMealType(mealTime.hour, 'breakfast') ? 1.0 : 0.0;
    features['is_lunch'] = _isMealType(mealTime.hour, 'lunch') ? 1.0 : 0.0;
    features['is_dinner'] = _isMealType(mealTime.hour, 'dinner') ? 1.0 : 0.0;
    features['is_snack'] = meal.isSnack ? 1.0 : 0.0;
    features['is_late_night'] = mealTime.hour >= 21 || mealTime.hour < 5 ? 1.0 : 0.0;

    // Time since last meal
    if (lastMealTime != null) {
      final minutesSinceLastMeal = mealTime.difference(lastMealTime).inMinutes.toDouble();
      features['minutes_since_last_meal'] = minutesSinceLastMeal;
      features['hours_since_last_meal'] = minutesSinceLastMeal / 60.0;
    } else {
      features['minutes_since_last_meal'] = 0.0;
      features['hours_since_last_meal'] = 0.0;
    }

    features['meals_today_count'] = mealsToday.toDouble();

    // === CONTEXT FEATURES ===
    if (context != null) {
      features['temperature_celsius'] = context.temperature ?? 15.0; // Default moderate temp
      features['pressure_hpa'] = context.barometricPressure ?? 1013.0; // Default sea level
      features['pressure_change_6h'] = context.pressureChange6h ?? 0.0;
      features['humidity'] = context.humidity ?? 50.0;
      features['is_high_humidity'] = context.isHighHumidity ? 1.0 : 0.0;
      features['is_pressure_dropping'] = context.isPressureDropping ? 1.0 : 0.0;

      // Weather condition (one-hot)
      features['weather_sunny'] = context.weatherCondition == 'sunny' ? 1.0 : 0.0;
      features['weather_rainy'] = context.weatherCondition == 'rainy' ? 1.0 : 0.0;
      features['weather_cloudy'] = context.weatherCondition == 'cloudy' ? 1.0 : 0.0;
      features['weather_stormy'] = context.weatherCondition == 'stormy' ? 1.0 : 0.0;

      // Time of day and season from context
      features['time_morning'] = context.timeOfDay == 'morning' ? 1.0 : 0.0;
      features['time_afternoon'] = context.timeOfDay == 'afternoon' ? 1.0 : 0.0;
      features['time_evening'] = context.timeOfDay == 'evening' ? 1.0 : 0.0;
      features['time_night'] = context.timeOfDay == 'night' ? 1.0 : 0.0;

      features['season_spring'] = context.season == 'spring' ? 1.0 : 0.0;
      features['season_summer'] = context.season == 'summer' ? 1.0 : 0.0;
      features['season_fall'] = context.season == 'fall' ? 1.0 : 0.0;
      features['season_winter'] = context.season == 'winter' ? 1.0 : 0.0;
    } else {
      // Default context values
      features['temperature_celsius'] = 15.0;
      features['pressure_hpa'] = 1013.0;
      features['pressure_change_6h'] = 0.0;
      features['humidity'] = 50.0;
      features['is_high_humidity'] = 0.0;
      features['is_pressure_dropping'] = 0.0;
      features['weather_sunny'] = 0.0;
      features['weather_rainy'] = 0.0;
      features['weather_cloudy'] = 0.0;
      features['weather_stormy'] = 0.0;
      features['time_morning'] = 0.0;
      features['time_afternoon'] = 0.0;
      features['time_evening'] = 0.0;
      features['time_night'] = 0.0;
      features['season_spring'] = 0.0;
      features['season_summer'] = 0.0;
      features['season_fall'] = 0.0;
      features['season_winter'] = 0.0;
    }

    return features;
  }

  /// Extract foods from meal metadata JSON
  static List<Map<String, dynamic>> _extractFoodsFromMetadata(String? metaData) {
    if (metaData == null || metaData.isEmpty) return [];

    try {
      final decoded = jsonDecode(metaData);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print('[FeatureExtractor] Error parsing metadata: $e');
    }
    return [];
  }

  /// Aggregate nutrition data from multiple foods
  static Map<String, double> _aggregateNutrition(List<Map<String, dynamic>> foods) {
    final totals = <String, double>{
      'proteins': 0.0,
      'fats': 0.0,
      'carbs': 0.0,
      'fiber': 0.0,
      'sugars': 0.0,
      'energy': 0.0,
    };

    for (final food in foods) {
      totals['proteins'] = totals['proteins']! + (food['proteins'] ?? 0.0);
      totals['fats'] = totals['fats']! + (food['fats'] ?? 0.0);
      totals['carbs'] = totals['carbs']! + (food['carbs'] ?? 0.0);
      totals['fiber'] = totals['fiber']! + (food['fiber'] ?? 0.0);
      totals['sugars'] = totals['sugars']! + (food['sugars'] ?? 0.0);
      totals['energy'] = totals['energy']! + (food['energy'] ?? 0.0);
    }

    return totals;
  }

  /// Get average NOVA group from foods
  static double _getAverageNovaGroup(List<Map<String, dynamic>> foods) {
    if (foods.isEmpty) return 1.0;

    double sum = 0.0;
    int count = 0;

    for (final food in foods) {
      final novaGroup = food['novaGroup'];
      if (novaGroup != null) {
        sum += novaGroup.toDouble();
        count++;
      }
    }

    return count > 0 ? sum / count : 1.0;
  }

  /// Determine if hour corresponds to meal type
  static bool _isMealType(int hour, String mealType) {
    switch (mealType) {
      case 'breakfast':
        return hour >= 6 && hour < 11;
      case 'lunch':
        return hour >= 11 && hour < 15;
      case 'dinner':
        return hour >= 18 && hour < 22;
      default:
        return false;
    }
  }

  /// Calculate cosine similarity between two feature vectors
  static double cosineSimilarity(Map<String, double> features1, Map<String, double> features2) {
    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (final key in features1.keys) {
      if (features2.containsKey(key)) {
        dotProduct += features1[key]! * features2[key]!;
        norm1 += features1[key]! * features1[key]!;
        norm2 += features2[key]! * features2[key]!;
      }
    }

    if (norm1 == 0.0 || norm2 == 0.0) return 0.0;

    return dotProduct / (sqrt(norm1) * sqrt(norm2));
  }

  /// Export feature names in order (for CSV header)
  static List<String> getFeatureNames() {
    return [
      // Meal tags (11)
      'tag_feculent', 'tag_proteine', 'tag_legume', 'tag_produit_laitier',
      'tag_fruit', 'tag_epices', 'tag_gras', 'tag_sucre', 'tag_fermente',
      'tag_gluten', 'tag_alcool',
      // Nutrition (9)
      'protein_g', 'fat_g', 'carb_g', 'fiber_g', 'sugar_g', 'energy_kcal',
      'protein_pct', 'fat_pct', 'carb_pct',
      // Processing (2)
      'nova_group', 'is_processed',
      // Timing (10)
      'hour_of_day', 'day_of_week', 'is_weekend', 'is_breakfast', 'is_lunch',
      'is_dinner', 'is_snack', 'is_late_night', 'minutes_since_last_meal',
      'hours_since_last_meal', 'meals_today_count',
      // Context weather (10)
      'temperature_celsius', 'pressure_hpa', 'pressure_change_6h', 'humidity',
      'is_high_humidity', 'is_pressure_dropping', 'weather_sunny', 'weather_rainy',
      'weather_cloudy', 'weather_stormy',
      // Context time/season (8)
      'time_morning', 'time_afternoon', 'time_evening', 'time_night',
      'season_spring', 'season_summer', 'season_fall', 'season_winter',
    ];
  }
}
