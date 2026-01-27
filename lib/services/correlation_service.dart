import 'dart:math';
import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';

/// Statistical correlation analysis service
class CorrelationService {
  final DatabaseHelper _db = DatabaseHelper();

  /// Calculate Pearson correlation coefficient for continuous variables
  /// Returns correlation coefficient (-1 to 1) and p-value
  Future<Map<String, double>> calculatePearsonCorrelation(
    List<double> feature,
    List<double> symptomSeverity,
  ) async {
    if (feature.length != symptomSeverity.length || feature.length < 3) {
      return {'correlation': 0.0, 'p_value': 1.0};
    }

    final n = feature.length;
    final meanX = feature.reduce((a, b) => a + b) / n;
    final meanY = symptomSeverity.reduce((a, b) => a + b) / n;

    double numerator = 0.0;
    double denomX = 0.0;
    double denomY = 0.0;

    for (int i = 0; i < n; i++) {
      final dx = feature[i] - meanX;
      final dy = symptomSeverity[i] - meanY;
      numerator += dx * dy;
      denomX += dx * dx;
      denomY += dy * dy;
    }

    if (denomX == 0.0 || denomY == 0.0) {
      return {'correlation': 0.0, 'p_value': 1.0};
    }

    final r = numerator / sqrt(denomX * denomY);

    // Calculate t-statistic and p-value
    final t = r * sqrt(n - 2) / sqrt(1 - r * r);
    final pValue = _calculatePValue(t, n - 2);

    return {'correlation': r, 'p_value': pValue};
  }

  /// Calculate Chi-squared test for categorical features
  /// Returns chi-squared statistic and p-value
  Future<Map<String, double>> calculateChiSquared(
    List<bool> categoricalFeature,
    List<bool> symptomOccurrence,
  ) async {
    if (categoricalFeature.length != symptomOccurrence.length || 
        categoricalFeature.length < 4) {
      return {'chi_squared': 0.0, 'p_value': 1.0};
    }

    // Create 2x2 contingency table
    int a = 0; // Feature present + Symptom occurred
    int b = 0; // Feature present + No symptom
    int c = 0; // Feature absent + Symptom occurred
    int d = 0; // Feature absent + No symptom

    for (int i = 0; i < categoricalFeature.length; i++) {
      if (categoricalFeature[i] && symptomOccurrence[i]) {
        a++;
      } else if (categoricalFeature[i] && !symptomOccurrence[i]) {
        b++;
      } else if (!categoricalFeature[i] && symptomOccurrence[i]) {
        c++;
      } else {
        d++;
      }
    }

    final n = a + b + c + d;
    final chiSquared = (n * (a * d - b * c) * (a * d - b * c)) /
        ((a + b) * (c + d) * (a + c) * (b + d)).toDouble();

    // Calculate p-value (df = 1 for 2x2 table)
    final pValue = _chiSquaredPValue(chiSquared, 1);

    return {'chi_squared': chiSquared, 'p_value': pValue};
  }

  /// Find optimal time window for symptom onset after meals
  /// Tests multiple windows (2h, 4h, 6h, 8h, 12h, 24h)
  /// Returns best window with highest correlation
  Future<Map<String, dynamic>> findOptimalTimeWindow() async {
    final windows = [2, 4, 6, 8, 12, 24];
    final results = <Map<String, dynamic>>[];

    for (final hours in windows) {
      final pairs = await _db.getMealSymptomPairs(hours);
      
      if (pairs.length < 10) continue; // Need minimum sample size

      // Calculate correlation for this window
      final symptomOccurred = pairs.map((p) => p['symptom_id'] != null).toList();
      final symptomCount = symptomOccurred.where((s) => s).length;
      final rate = symptomCount / pairs.length;

      results.add({
        'hours': hours,
        'sample_size': pairs.length,
        'symptom_rate': rate,
        'symptom_count': symptomCount,
      });
    }

    // Find window with highest symptom rate (most predictive)
    if (results.isEmpty) {
      return {'hours': 8, 'sample_size': 0, 'symptom_rate': 0.0};
    }

    results.sort((a, b) => (b['symptom_rate'] as double)
        .compareTo(a['symptom_rate'] as double));

    return results.first;
  }

  /// Detect if ingredient combinations have higher correlation than individual
  Future<List<Map<String, dynamic>>> detectCombinationEffects({
    int minOccurrences = 5,
  }) async {
    final pairs = await _db.getMealSymptomPairs(8);
    final combinations = <String, Map<String, dynamic>>{};

    for (final pair in pairs) {
      final tags = (pair['tags'] as String).split(',');
      
      // Check all pairs of tags
      for (int i = 0; i < tags.length - 1; i++) {
        for (int j = i + 1; j < tags.length; j++) {
          final tag1 = tags[i].trim();
          final tag2 = tags[j].trim();
          final comboKey = [tag1, tag2]..sort();
          final comboName = comboKey.join(' + ');

          combinations.putIfAbsent(comboName, () => {
            'count': 0,
            'symptom_count': 0,
            'tag1': tag1,
            'tag2': tag2,
          });

          combinations[comboName]!['count'] = 
              (combinations[comboName]!['count'] as int) + 1;
          
          if (pair['symptom_id'] != null) {
            combinations[comboName]!['symptom_count'] = 
                (combinations[comboName]!['symptom_count'] as int) + 1;
          }
        }
      }
    }

    // Filter and calculate rates
    final results = <Map<String, dynamic>>[];
    for (final entry in combinations.entries) {
      final data = entry.value;
      final count = data['count'] as int;
      
      if (count >= minOccurrences) {
        final symptomCount = data['symptom_count'] as int;
        final rate = symptomCount / count;

        results.add({
          'combination': entry.key,
          'tag1': data['tag1'],
          'tag2': data['tag2'],
          'occurrences': count,
          'symptom_count': symptomCount,
          'symptom_rate': rate,
        });
      }
    }

    // Sort by symptom rate descending
    results.sort((a, b) => 
        (b['symptom_rate'] as double).compareTo(a['symptom_rate'] as double));

    return results;
  }

  /// Detect personal macro thresholds using binning approach
  /// Returns threshold value where symptom risk increases significantly
  Future<Map<String, dynamic>?> detectMacroThreshold(
    String macroName, // 'proteins', 'fats', 'carbs', 'fiber', 'sugars'
    {int bins = 10}
  ) async {
    final pairs = await _db.getMealSymptomPairs(8);
    
    if (pairs.length < 20) return null;

    // Extract macro values and symptom occurrences
    final macroValues = <double>[];
    final hasSymptom = <bool>[];

    for (final pair in pairs) {
      final metaData = pair['meta_data'] as String?;
      if (metaData == null) continue;

      // Parse nutrition from metadata
      try {
        final nutrition = _extractNutritionFromMetadata(metaData, macroName);
        if (nutrition > 0) {
          macroValues.add(nutrition);
          hasSymptom.add(pair['symptom_id'] != null);
        }
      } catch (e) {
        continue;
      }
    }

    if (macroValues.length < 20) return null;

    // Create bins
    final minVal = macroValues.reduce(min);
    final maxVal = macroValues.reduce(max);
    final binSize = (maxVal - minVal) / bins;

    final binSymptomRates = <double>[];
    final binCounts = <int>[];

    for (int i = 0; i < bins; i++) {
      final binStart = minVal + i * binSize;
      final binEnd = binStart + binSize;

      int binCount = 0;
      int symptomCount = 0;

      for (int j = 0; j < macroValues.length; j++) {
        if (macroValues[j] >= binStart && macroValues[j] < binEnd) {
          binCount++;
          if (hasSymptom[j]) symptomCount++;
        }
      }

      binCounts.add(binCount);
      binSymptomRates.add(binCount > 0 ? symptomCount / binCount : 0.0);
    }

    // Find threshold where symptom rate increases significantly
    // Look for largest jump in symptom rate
    double maxJump = 0.0;
    int thresholdBin = -1;

    for (int i = 0; i < bins - 1; i++) {
      if (binCounts[i] >= 3 && binCounts[i + 1] >= 3) {
        final jump = binSymptomRates[i + 1] - binSymptomRates[i];
        if (jump > maxJump) {
          maxJump = jump;
          thresholdBin = i;
        }
      }
    }

    if (thresholdBin == -1 || maxJump < 0.2) return null;

    final thresholdValue = minVal + (thresholdBin + 1) * binSize;
    final baselineRate = binSymptomRates[thresholdBin];
    final elevatedRate = binSymptomRates[thresholdBin + 1];
    final riskIncrease = (elevatedRate - baselineRate) * 100;

    return {
      'macro_name': macroName,
      'threshold_value': thresholdValue,
      'risk_increase_pct': riskIncrease,
      'baseline_rate': baselineRate,
      'elevated_rate': elevatedRate,
      'sample_size': macroValues.length,
      'confidence': _calculateConfidence(binCounts[thresholdBin], binCounts[thresholdBin + 1]),
    };
  }

  /// Extract nutrition value from metadata JSON
  double _extractNutritionFromMetadata(String metaData, String macroName) {
    // Simplified extraction - assumes metadata contains nutrition data
    // In real implementation, parse JSON properly
    try {
      if (metaData.contains('"$macroName":')) {
        final regex = RegExp('"$macroName":(\\d+\\.?\\d*)');
        final match = regex.firstMatch(metaData);
        if (match != null) {
          return double.parse(match.group(1)!);
        }
      }
    } catch (e) {
      // Ignore parse errors
    }
    return 0.0;
  }

  /// Calculate p-value from t-statistic (two-tailed test)
  double _calculatePValue(double t, int df) {
    // Simplified p-value calculation
    // For production, use proper statistical library
    final tAbs = t.abs();
    
    if (tAbs > 2.576) return 0.01; // 99% confidence
    if (tAbs > 1.96) return 0.05; // 95% confidence
    if (tAbs > 1.645) return 0.10; // 90% confidence
    
    return 0.5; // Not significant
  }

  /// Calculate chi-squared p-value
  double _chiSquaredPValue(double chiSquared, int df) {
    // Simplified critical values for df=1
    if (chiSquared > 10.828) return 0.001;
    if (chiSquared > 6.635) return 0.01;
    if (chiSquared > 3.841) return 0.05;
    if (chiSquared > 2.706) return 0.10;
    
    return 0.5;
  }

  /// Calculate confidence score based on sample sizes
  double _calculateConfidence(int n1, int n2) {
    final minSample = min(n1, n2);
    
    if (minSample >= 30) return 1.0; // High confidence
    if (minSample >= 15) return 0.7; // Medium confidence
    if (minSample >= 5) return 0.4; // Low confidence
    
    return 0.1; // Very low confidence
  }

  /// Cache correlation results in database
  Future<void> cacheCorrelation(
    String featureName,
    String featureType,
    double correlation,
    double pValue,
    int sampleSize,
    double confidenceLow,
    double confidenceHigh,
  ) async {
    final dbInstance = await _db.database;
    
    await dbInstance.insert(
      'correlation_cache',
      {
        'feature_name': featureName,
        'feature_type': featureType,
        'correlation_coefficient': correlation,
        'p_value': pValue,
        'sample_size': sampleSize,
        'confidence_interval_low': confidenceLow,
        'confidence_interval_high': confidenceHigh,
        'last_updated': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get cached correlations
  Future<List<Map<String, dynamic>>> getCachedCorrelations({
    String? featureType,
    double? minAbsCorrelation,
    double? maxPValue,
  }) async {
    final dbInstance = await _db.database;
    
    String whereClause = '1=1';
    final whereArgs = <dynamic>[];

    if (featureType != null) {
      whereClause += ' AND feature_type = ?';
      whereArgs.add(featureType);
    }

    if (minAbsCorrelation != null) {
      whereClause += ' AND ABS(correlation_coefficient) >= ?';
      whereArgs.add(minAbsCorrelation);
    }

    if (maxPValue != null) {
      whereClause += ' AND p_value <= ?';
      whereArgs.add(maxPValue);
    }

    final results = await dbInstance.query(
      'correlation_cache',
      where: whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'ABS(correlation_coefficient) DESC',
    );

    return results;
  }
}
