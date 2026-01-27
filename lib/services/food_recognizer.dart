import 'dart:io';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../food_model.dart';

class FoodPrediction {
  final String foodName;
  final double confidence;
  final int classIndex;

  FoodPrediction({
    required this.foodName,
    required this.confidence,
    required this.classIndex,
  });

  @override
  String toString() =>
      'FoodPrediction(name: $foodName, confidence: ${(confidence * 100).toStringAsFixed(1)}%)';
}

class FoodRecognizer {
  static final FoodRecognizer _instance = FoodRecognizer._internal();
  Interpreter? _interpreter;
  List<String>? _labels;
  bool _isInitialized = false;

  factory FoodRecognizer() {
    return _instance;
  }

  FoodRecognizer._internal();

  /// Initialize the model (load TFLite model and labels)
  Future<void> loadModel() async {
    if (_isInitialized) {
      print('[FoodRecognizer] Model already loaded');
      return;
    }

    try {
      print('[FoodRecognizer] Loading TFLite model...');

      // Load TFLite model
      _interpreter = await Interpreter.fromAsset(
        'assets/models/food_classifier.tflite',
      );

      // Load labels
      final labelData = await rootBundle.loadString(
        'assets/models/food_labels.txt',
      );
      _labels = labelData
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();

      print('[FoodRecognizer] Model loaded successfully');
      print(
        '[FoodRecognizer] Input shape: ${_interpreter!.getInputTensor(0).shape}',
      );
      print(
        '[FoodRecognizer] Output shape: ${_interpreter!.getOutputTensor(0).shape}',
      );
      print('[FoodRecognizer] Total classes: ${_labels!.length}');

      _isInitialized = true;
    } catch (e) {
      print('[FoodRecognizer] Error loading model: $e');
      rethrow;
    }
  }

  /// Recognize food from image file path
  Future<List<FoodPrediction>> recognizeFood(String imagePath) async {
    if (!_isInitialized) {
      await loadModel();
    }

    if (_interpreter == null || _labels == null) {
      throw Exception('Model not initialized');
    }

    try {
      print('[FoodRecognizer] Processing image: $imagePath');

      // 1. Load image from file
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw Exception('Image file not found: $imagePath');
      }

      final imageBytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // 2. Preprocess image (resize to 224x224 for MobileNet)
      final inputSize = 224;
      image = img.copyResize(image, width: inputSize, height: inputSize);

      // 3. Convert to normalized Float32 array [1, 224, 224, 3]
      final input = _imageToFloat32List(image, inputSize);

      // 4. Prepare output tensor [1, num_classes]
      final output = List.filled(
        1 * _labels!.length,
        0.0,
      ).reshape([1, _labels!.length]);

      // 5. Run inference
      final startTime = DateTime.now();
      _interpreter!.run(input, output);
      final inferenceTime = DateTime.now().difference(startTime).inMilliseconds;

      print('[FoodRecognizer] Inference completed in ${inferenceTime}ms');

      // 6. Parse top predictions
      final predictions = _parseTopPredictions(output[0], topK: 3);

      for (var pred in predictions) {
        print('[FoodRecognizer] ${pred}');
      }

      return predictions;
    } catch (e) {
      print('[FoodRecognizer] Error during recognition: $e');
      rethrow;
    }
  }

  /// Convert image to Float32List normalized for MobileNet input
  List<List<List<List<double>>>> _imageToFloat32List(
    img.Image image,
    int inputSize,
  ) {
    final result = List.generate(
      1,
      (_) => List.generate(
        inputSize,
        (y) => List.generate(inputSize, (x) {
          final pixel = image.getPixel(x, y);
          return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
        }),
      ),
    );

    return result;
  }

  /// Parse top K predictions from output tensor
  List<FoodPrediction> _parseTopPredictions(
    List<double> outputs, {
    int topK = 3,
  }) {
    // Create list of (index, score) pairs
    final predictions = <FoodPrediction>[];

    for (int i = 0; i < outputs.length; i++) {
      predictions.add(
        FoodPrediction(
          foodName: _labels![i],
          confidence: outputs[i],
          classIndex: i,
        ),
      );
    }

    // Sort by confidence (descending)
    predictions.sort((a, b) => b.confidence.compareTo(a.confidence));

    // Return top K
    return predictions.take(topK).toList();
  }

  /// Convert predictions to FoodModel list for UI
  Future<List<FoodModel>> predictionsToFoodModels(
    List<FoodPrediction> predictions,
  ) async {
    final foods = <FoodModel>[];

    for (var pred in predictions) {
      // Create basic FoodModel from prediction
      final food = FoodModel(
        id: null, // Will be assigned by DB if saved
        name: _capitalizeFood(pred.foodName),
        category: _inferCategory(pred.foodName),
        tags: [
          'IA Détecté',
          '${(pred.confidence * 100).toStringAsFixed(0)}% confiance',
        ],
        proteins: null,
        fats: null,
        carbs: null,
        fiber: null,
        sugars: null,
        brand: null,
        imageUrl: null,
        barcode: null,
      );

      foods.add(food);
    }

    return foods;
  }

  /// Capitalize food name (e.g., "chicken curry" -> "Chicken Curry")
  String _capitalizeFood(String foodName) {
    return foodName
        .split(' ')
        .map(
          (word) =>
              word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
        )
        .join(' ');
  }

  /// Infer category from food name (simple heuristic)
  String _inferCategory(String foodName) {
    final lower = foodName.toLowerCase();

    if (lower.contains('salad')) return 'Légumes';
    if (lower.contains('cake') ||
        lower.contains('dessert') ||
        lower.contains('ice cream') ||
        lower.contains('pudding') ||
        lower.contains('mousse') ||
        lower.contains('tiramisu')) {
      return 'Dessert';
    }
    if (lower.contains('pizza') ||
        lower.contains('burger') ||
        lower.contains('sandwich') ||
        lower.contains('hot dog')) {
      return 'Fast-Food';
    }
    if (lower.contains('chicken') ||
        lower.contains('beef') ||
        lower.contains('pork') ||
        lower.contains('steak') ||
        lower.contains('ribs')) {
      return 'Viande';
    }
    if (lower.contains('fish') ||
        lower.contains('salmon') ||
        lower.contains('sushi') ||
        lower.contains('sashimi') ||
        lower.contains('shrimp')) {
      return 'Poisson';
    }
    if (lower.contains('rice') ||
        lower.contains('pasta') ||
        lower.contains('noodle') ||
        lower.contains('spaghetti') ||
        lower.contains('ramen')) {
      return 'Féculent';
    }
    if (lower.contains('bread') ||
        lower.contains('toast') ||
        lower.contains('pancake') ||
        lower.contains('waffle')) {
      return 'Pain';
    }
    if (lower.contains('soup') ||
        lower.contains('chowder') ||
        lower.contains('bisque')) {
      return 'Soupe';
    }

    return 'Plat Préparé';
  }

  /// Dispose resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _labels = null;
    _isInitialized = false;
    print('[FoodRecognizer] Model disposed');
  }
}
