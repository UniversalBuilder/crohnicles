import '../database_helper.dart';
import '../ml/model_manager.dart';

import 'statistical_engine.dart';

/// Service for managing ML model training
class TrainingService {
  static final TrainingService _instance = TrainingService._internal();

  factory TrainingService() {
    return _instance;
  }

  TrainingService._internal();

  final DatabaseHelper _db = DatabaseHelper();
  bool _isTraining = false;

  /// Check if we have sufficient data to train models
  Future<TrainingDataStatus> checkDataAvailability() async {
    return await _db.checkTrainingDataAvailability();
  }

  /// Check if training is supported on current platform
  bool isTrainingSupported() {
    // Now supported on all platforms thanks to StatisticalEngine
    return true; 
  }

  /// Trigger manual training process
  Future<TrainingResult> trainModels() async {
    if (_isTraining) {
      return TrainingResult(
        success: false,
        message: 'Analyse déjà en cours',
      );
    }

    _isTraining = true;
    try {
      print('[TrainingService] Starting statistical analysis...');

      // Check data availability first
      final dataStatus = await checkDataAvailability();

      // Use Statistical Engine (Cross-platform)
      final result = await StatisticalEngine().train();
      
      if (result.success) {
        // Save training history
        final correlationCount = result.correlationCount ?? 0;
        await _db.saveTrainingHistory(
          mealCount: dataStatus.mealCount,
          symptomCount: dataStatus.symptomCount,
          correlationCount: correlationCount,
          notes: 'Analyse statistique: $correlationCount corrélations identifiées',
        );
        
        try {
          final modelManager = ModelManager();
          await modelManager.initialize();
        } catch (_) {}
      }
      return result;

    } catch (e) {
      print('[TrainingService] Analysis failed: $e');
      return TrainingResult(success: false, message: 'Erreur d\'analyse: $e');
    } finally {
      _isTraining = false;
    }
  }

  /// Check if training should be triggered automatically
  Future<bool> shouldAutoTrain() async {
    // Get latest training history
    final history = await _db.getLatestTrainingHistory();

    if (history.isEmpty) {
      // Never trained - check if we have enough data
      final dataStatus = await checkDataAvailability();
      return dataStatus.hasEnoughData;
    }

    // Check if it's been more than 7 days since last training
    final trainedAt = DateTime.parse(history.first['trained_at'] as String);
    final daysSince = DateTime.now().difference(trainedAt).inDays;
    if (daysSince > 7) {
      print('[TrainingService] Last training was $daysSince days ago');
      return true;
    }

    return false;
  }
}


/// Status of available training data
class TrainingDataStatus {
  final int mealCount;
  final int symptomCount;
  final bool hasEnoughData;
  final String message;

  TrainingDataStatus({
    required this.mealCount,
    required this.symptomCount,
    required this.hasEnoughData,
    required this.message,
  });
}

/// Result of training operation
class TrainingResult {
  final bool success;
  final String message;
  final int? modelsCount;
  final int? correlationCount;

  TrainingResult({
    required this.success,
    required this.message,
    this.modelsCount,
    this.correlationCount,
  });
}
