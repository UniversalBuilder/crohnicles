import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../food_model.dart';

class OFFService {
  static final OFFService _instance = OFFService._internal();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const String _apiBaseUrl = 'https://world.openfoodfacts.org/api/v2';
  static const String _userAgent = 'Crohnicles - Flutter App - Version 1.0';

  factory OFFService() {
    return _instance;
  }

  OFFService._internal();

  /// Validate barcode format (EAN-8 or EAN-13)
  bool _isValidBarcode(String barcode) {
    if (barcode.isEmpty) return false;
    final cleaned = barcode.trim();
    // Check if it's numeric and either 8 or 13 digits
    if (!RegExp(r'^\d+$').hasMatch(cleaned)) return false;
    return cleaned.length == 8 || cleaned.length == 13;
  }

  /// Fetch product by barcode with optional cache
  Future<FoodModel?> fetchByBarcode(
    String barcode, {
    bool forceRefresh = false,
  }) async {
    if (!_isValidBarcode(barcode)) {
      return null;
    }

    // Check cache first if not forcing refresh
    if (!forceRefresh) {
      final cached = await _loadFromCache(barcode);
      if (cached != null) {
        return cached;
      }
    }

    try {
      // Fetch from OpenFoodFacts API using HTTP
      final response = await http
          .get(
            Uri.parse('$_apiBaseUrl/product/$barcode.json'),
            headers: {'User-Agent': _userAgent},
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        return null;
      }

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (data['status'] != 1 || data['product'] == null) {
        return null;
      }

      final Map<String, dynamic> product = data['product'];
      final FoodModel food = _mapProductToFoodModel(product, barcode);

      // Save to cache
      await _saveToCache(barcode, food);

      return food;
    } on SocketException catch (e) {
      // Network error - return null silently
      return null;
    } on TimeoutException catch (e) {
      // Timeout - return null silently
      return null;
    } catch (e) {
      // Error fetching product - return null silently
      return null;
    }
  }

  /// Search products by query
  Future<List<FoodModel>> searchProducts(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      // Rate limiting: 200ms delay to avoid API throttling (max 5 req/sec)
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Encode query properly for URL
      final encodedQuery = Uri.encodeQueryComponent(query.trim());

      // Use the CGI search endpoint which properly handles text search
      // tagtype_0=products&tag_contains_0=contains&tag_0=query
      final url =
          'https://world.openfoodfacts.org/cgi/search.pl?'
          'search_terms=$encodedQuery&'
          'search_simple=1&'
          'action=process&'
          'page_size=20&'
          'json=1';

      // Search using OpenFoodFacts API
      final response = await http
          .get(Uri.parse(url), headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        return [];
      }

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (data['products'] == null) {
        return [];
      }

      final List<dynamic> products = data['products'];

      return products
          .map(
            (product) => _mapProductToFoodModel(product, product['code'] ?? ''),
          )
          .toList();
    } on SocketException catch (e) {
      // Network error - return empty list
      return [];
    } on TimeoutException catch (e) {
      // Timeout - return empty list
      return [];
    } catch (e) {
      // Error searching - return empty list
      return [];
    }
  }

  /// Map OpenFoodFacts Product to FoodModel
  FoodModel _mapProductToFoodModel(
    Map<String, dynamic> product,
    String barcode,
  ) {
    final String name =
        product['product_name'] ??
        product['product_name_fr'] ??
        'Produit inconnu';
    final String? brand = product['brands'];
    final String? imageUrl = product['image_front_url'] ?? product['image_url'];

    // Extract nutrition per 100g (handle nulls silently)
    final nutriments = product['nutriments'] ?? {};
    final double energy =
        _toDouble(
          nutriments['energy-kcal_100g'] ?? nutriments['energy_100g'],
        ) ??
        0.0;
    final double proteins = _toDouble(nutriments['proteins_100g']) ?? 0.0;
    final double fats = _toDouble(nutriments['fat_100g']) ?? 0.0;
    final double carbs = _toDouble(nutriments['carbohydrates_100g']) ?? 0.0;
    final double fiber = _toDouble(nutriments['fiber_100g']) ?? 0.0;
    final double sugars = _toDouble(nutriments['sugars_100g']) ?? 0.0;

    // Quality indicators
    final String? nutriScore = product['nutriscore_grade']
        ?.toString()
        .toUpperCase();
    final int? novaGroup = product['nova_group'] is int
        ? product['nova_group']
        : null;

    // Determine category based on categories_tags
    String category = 'Snack';
    final List<dynamic> categoriesTags = product['categories_tags'] ?? [];
    if (categoriesTags.isNotEmpty) {
      // Check bread and spreads first (more specific)
      if (categoriesTags.any(
        (t) =>
            t.toString().contains('bread') ||
            t.toString().contains('pain') ||
            t.toString().contains('baguette') ||
            t.toString().contains('sandwich-bread'),
      )) {
        category = 'Féculent';
      } else if (categoriesTags.any(
        (t) =>
            t.toString().contains('spread') ||
            t.toString().contains('jam') ||
            t.toString().contains('confiture') ||
            t.toString().contains('honey') ||
            t.toString().contains('miel') ||
            t.toString().contains('chocolate-spread'),
      )) {
        category = 'Snack';
      } else if (categoriesTags.any(
        (t) =>
            t.toString().contains('pasta') ||
            t.toString().contains('rice') ||
            t.toString().contains('riz') ||
            t.toString().contains('cereals') ||
            t.toString().contains('céréales'),
      )) {
        category = 'Féculent';
      } else if (categoriesTags.any(
        (t) =>
            t.toString().contains('meat') ||
            t.toString().contains('viande') ||
            t.toString().contains('fish') ||
            t.toString().contains('poisson') ||
            t.toString().contains('poultry') ||
            t.toString().contains('poulet'),
      )) {
        category = 'Protéine';
      } else if (categoriesTags.any(
        (t) =>
            t.toString().contains('dairy') ||
            t.toString().contains('laitier') ||
            t.toString().contains('yogurt') ||
            t.toString().contains('yaourt'),
      )) {
        category = 'Snack';
      } else if (categoriesTags.any(
        (t) =>
            t.toString().contains('meal') ||
            t.toString().contains('pizza') ||
            t.toString().contains('plat') ||
            t.toString().contains('sandwich'),
      )) {
        category = 'Repas';
      } else if (categoriesTags.any(
        (t) =>
            t.toString().contains('beverage') ||
            t.toString().contains('boisson') ||
            t.toString().contains('drink'),
      )) {
        category = 'Boisson';
      }
    }

    // Extract allergens
    List<String> allergensList = [];
    final List<dynamic> allergensRaw = product['allergens_tags'] ?? [];
    for (var allergen in allergensRaw) {
      final cleaned = allergen
          .toString()
          .replaceAll('en:', '')
          .replaceAll('-', ' ');
      allergensList.add(cleaned);
    }

    // Build tags from analysis
    List<String> tags = [];

    // Add allergen-based tags
    if (allergensList.any((a) => a.contains('gluten'))) tags.add('Gluten');
    if (allergensList.any((a) => a.contains('milk') || a.contains('lactose'))) {
      tags.add('Lactose');
    }
    if (allergensList.any((a) => a.contains('nuts'))) tags.add('Noix');

    // Add nutrition-based tags
    if (sugars > 10.0) tags.add('Sucre');
    if (fats > 15.0) tags.add('Gras');
    if (fiber > 5.0) tags.add('Fibres');

    // Add NOVA-based tags
    if (novaGroup == 4) tags.add('Industriel');
    if (novaGroup == 1) tags.add('Naturel');

    // Add category tag
    if (category == 'Boisson') tags.add('Boisson');
    if (category == 'Protéine') tags.add('Protéine');
    if (category == 'Féculent') tags.add('Féculent');

    return FoodModel(
      name: name,
      category: category,
      tags: tags,
      barcode: barcode,
      brand: brand,
      imageUrl: imageUrl,
      energy: energy,
      proteins: proteins,
      fats: fats,
      carbs: carbs,
      fiber: fiber,
      sugars: sugars,
      nutriScore: nutriScore,
      novaGroup: novaGroup,
      allergens: allergensList,
      servingSize: 100.0,
      isBasicFood: false,
    );
  }

  /// Helper to convert dynamic to double
  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Save product to cache
  Future<void> _saveToCache(String barcode, FoodModel food) async {
    try {
      final db = await _dbHelper.database;
      final int timestamp = DateTime.now().millisecondsSinceEpoch;
      final String foodData = jsonEncode(food.toMap());

      await db.insert('products_cache', {
        'barcode': barcode,
        'foodData': foodData,
        'timestamp': timestamp,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      // Silently fail cache save
    }
  }

  /// Load product from cache
  Future<FoodModel?> _loadFromCache(String barcode) async {
    try {
      final db = await _dbHelper.database;
      final int cutoff = DateTime.now()
          .subtract(const Duration(days: 90))
          .millisecondsSinceEpoch;

      final List<Map<String, dynamic>> results = await db.query(
        'products_cache',
        where: 'barcode = ? AND timestamp > ?',
        whereArgs: [barcode, cutoff],
      );

      if (results.isEmpty) return null;

      final String foodData = results.first['foodData'] as String;
      final Map<String, dynamic> map = jsonDecode(foodData);
      return FoodModel.fromMap(map);
    } catch (e) {
      // Cache load failed - return null
      return null;
    }
  }
}
