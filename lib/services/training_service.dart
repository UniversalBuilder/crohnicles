import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../database_helper.dart';
import '../symptom_taxonomy.dart';
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
    // 0. Use Statistical Engine on Mobile
    if (Platform.isAndroid || Platform.isIOS) {
       _isTraining = true;
       try {
         final result = await StatisticalEngine().train();
         if (result.success) {
            // Reload model manager to pick up new stats
            try {
              final modelManager = ModelManager();
              await modelManager.initialize();
            } catch (_) {}
         }
         return result;
       } finally {
         _isTraining = false;
       }
    }

    // Check platform support first
    if (!isTrainingSupported()) {
      return TrainingResult(
        success: false,
        message:
            'L\'entraînement n\'est disponible que sur ordinateur (Windows/Mac/Linux).\n\nSur mobile, utilisez les modèles pré-entraînés ou synchronisez depuis votre ordinateur.',
      );
    }

    if (_isTraining) {
      return TrainingResult(
        success: false,
        message: 'Training already in progress',
      );
    }

    _isTraining = true;
    try {
      print('[TrainingService] Starting training process...');

      // 1. Check data availability
      final dataStatus = await checkDataAvailability();
      if (!dataStatus.hasEnoughData) {
        return TrainingResult(
          success: false,
          message:
              'Insufficient data: ${dataStatus.mealCount} meals (need 30+)',
        );
      }

      // 2. Get database path
      final dbPath = await _getDatabasePath();
      print('[TrainingService] Database path: $dbPath');

      // 3. Run Python training script
      final scriptPath = await _getTrainingScriptPath();
      print('[TrainingService] Script path: $scriptPath');

      final result = await _runPythonTraining(scriptPath, dbPath);

      if (!result.success) {
        return result;
      }

      // 4. Verify models were created
      final trainedModels = await _verifyModels();
      if (trainedModels.isEmpty) {
        return TrainingResult(
          success: false,
          message:
              'Aucun modèle n\'a pu être entraîné.\n\nVérifiez que vous avez suffisamment de données (30+ repas avec symptômes corrélés).',
        );
      }

      // Success message with model details (7 possible models)
      final totalModels = SymptomTaxonomy.models.length; // Should be 7
      final modelList = trainedModels.map((m) => m.toUpperCase()).join(', ');
      final message = trainedModels.length == totalModels
          ? 'Tous les modèles ont été entraînés avec succès!'
          : 'Entraînement réussi!\n\nModèles créés: $modelList\n\n(${totalModels - trainedModels.length} modèle(s) ignoré(s) - données insuffisantes)';

      print(
        '[TrainingService] ✓ Training complete: ${trainedModels.length}/$totalModels model(s)',
      );

      // Reload ModelManager to refresh status
      try {
        final modelManager = ModelManager();
        await modelManager.initialize();
        print('[TrainingService] ModelManager reloaded successfully');
      } catch (e) {
        print('[TrainingService] Failed to reload ModelManager: $e');
      }

      return TrainingResult(
        success: true,
        message: message,
        modelsCount: trainedModels.length,
        f1Score: 0.0,
      );
    } catch (e) {
      print('[TrainingService] Training failed: $e');
      return TrainingResult(success: false, message: 'Training error: $e');
    } finally {
      _isTraining = false;
    }
  }

  /// Get path to SQLite database
  Future<String> _getDatabasePath() async {
    if (Platform.isWindows) {
      final appDir = await getApplicationDocumentsDirectory();
      return '${appDir.path}\\crohnicles.db';
    } else if (Platform.isAndroid || Platform.isIOS) {
      final appDir = await getApplicationDocumentsDirectory();
      return '${appDir.path}/crohnicles.db';
    } else {
      throw UnsupportedError('Platform not supported for training');
    }
  }

  /// Get path to training script
  Future<String> _getTrainingScriptPath() async {
    // During development, script is in project directory
    // For production, would need to bundle Python runtime
    final currentDir = Directory.current.path;
    if (Platform.isWindows) {
      return '$currentDir\\training\\train_models.py';
    } else {
      // Android/iOS: Training not supported on mobile
      throw UnsupportedError('Training not available on mobile devices');
    }
  }

  /// Run Python training script
  Future<TrainingResult> _runPythonTraining(
    String scriptPath,
    String dbPath,
  ) async {
    try {
      print('[TrainingService] Executing: python $scriptPath');
      print('[TrainingService] DB Path: $dbPath');

      // Set environment variable for database path
      final environment = <String, String>{'CROHNICLES_DB_PATH': dbPath};

      final process = await Process.start(
        'python',
        [scriptPath],
        environment: environment,
        workingDirectory: Directory(scriptPath).parent.path,
      );

      // Capture output with error-tolerant UTF-8 decoder
      final output = StringBuffer();
      final errors = StringBuffer();

      process.stdout.transform(const Utf8Decoder(allowMalformed: true)).listen((
        data,
      ) {
        print('[Python] $data');
        output.write(data);
      });

      process.stderr.transform(const Utf8Decoder(allowMalformed: true)).listen((
        data,
      ) {
        print('[Python Error] $data');
        errors.write(data);
      });

      final exitCode = await process.exitCode;

      if (exitCode != 0) {
        return TrainingResult(
          success: false,
          message: 'Python script failed (exit code $exitCode)',
        );
      }

      // Verify success by checking if model files were created
      // More reliable than parsing output with special characters
      final trainedModels = await _verifyModels();
      if (trainedModels.isEmpty) {
        return TrainingResult(
          success: false,
          message:
              'Training script completed but no models were created.\n\nCheck that you have sufficient symptom correlations (4-8h after meals).',
        );
      }

      return TrainingResult(
        success: true,
        message:
            'Python training completed: ${trainedModels.length} model(s) created',
      );
    } catch (e) {
      return TrainingResult(
        success: false,
        message: 'Failed to run Python script: $e',
      );
    }
  }

  /// Verify that at least one model JSON file was created
  Future<List<String>> _verifyModels() async {
    try {
      final currentDir = Directory.current.path;
      final modelsDir = Directory('$currentDir\\assets\\models');

      if (!await modelsDir.exists()) {
        print('[TrainingService] Models directory does not exist');
        return [];
      }

      // Check all 7 symptom types from SymptomTaxonomy
      final possibleModels = SymptomTaxonomy.models
          .map((config) => '${config.modelKey}_predictor.json')
          .toList();

      final foundModels = <String>[];
      for (final modelFile in possibleModels) {
        final file = File('${modelsDir.path}\\$modelFile');
        if (await file.exists()) {
          foundModels.add(modelFile.replaceAll('_predictor.json', ''));
          print('[TrainingService] ✓ Found model: $modelFile');
        } else {
          print(
            '[TrainingService] ✗ Missing model: $modelFile (normal si pas assez de données)',
          );
        }
      }

      if (foundModels.isEmpty) {
        print('[TrainingService] ✗ No models were created');
      } else {
        print(
          '[TrainingService] ✓ ${foundModels.length} model(s) created: ${foundModels.join(", ")}',
        );
      }
      return foundModels;
    } catch (e) {
      print('[TrainingService] Error verifying models: $e');
      return [];
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

    // Check if F1 score is degrading
    final latestF1 = history.first['f1_score'] as double;
    if (latestF1 < 0.6) {
      print('[TrainingService] F1 score degraded: $latestF1 < 0.6');
      return true;
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
  final double? f1Score;

  TrainingResult({
    required this.success,
    required this.message,
    this.modelsCount,
    this.f1Score,
  });
}
