import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'food_model.dart';
import 'data/generic_foods.dart';
import 'services/off_service.dart';
import 'services/training_service.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static Completer<Database>? _dbOpenCompleter;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    if (_dbOpenCompleter != null) {
      return _dbOpenCompleter!.future;
    }
    _dbOpenCompleter = Completer();
    try {
      _database = await _initDatabase();
      _dbOpenCompleter!.complete(_database!);
      return _database!;
    } catch (e) {
      _dbOpenCompleter!.completeError(e);
      _dbOpenCompleter = null;
      rethrow;
    }
  }

  Future<Database> _initDatabase() async {
    String dbPath;

    // Use different paths for different platforms
    if (kIsWeb) {
      dbPath = 'crohnicles.db';
    } else {
      // For desktop/mobile, use proper app documents directory
      final documentsDirectory = await getApplicationDocumentsDirectory();
      dbPath = join(documentsDirectory.path, 'crohnicles.db');
      print('📁 Database path: $dbPath');
    }

    return await openDatabase(
      dbPath,
      version: 9,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    print('[DB] Creating database version $version');
    await db.execute('''
      CREATE TABLE events(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT,
        dateTime TEXT,
        title TEXT,
        subtitle TEXT,
        severity INTEGER,
        tags TEXT,
        isUrgent INTEGER,
        isSnack INTEGER,
        imagePath TEXT,
        meta_data TEXT,
        context_data TEXT
      )
    ''');

    await _createFoodsTable(db);

    // Create products cache table for OpenFoodFacts
    await db.execute('''
      CREATE TABLE products_cache(
        barcode TEXT PRIMARY KEY,
        foodData TEXT,
        timestamp INTEGER
      )
    ''');

    // ML and Analytics tables
    await _createMLTables(db);

    print('[DB] Seeding generic foods...');
    await _seedGenericFoods(db);
    print('[DB] Cleaning old cache...');
    await cleanOldCache(db);
    print('[DB] Database created successfully');
  }

  Future<void> _createMLTables(Database db) async {
    // Correlation cache for storing calculated correlations
    await db.execute('''
      CREATE TABLE correlation_cache(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        feature_name TEXT,
        feature_type TEXT,
        correlation_coefficient REAL,
        p_value REAL,
        sample_size INTEGER,
        confidence_interval_low REAL,
        confidence_interval_high REAL,
        last_updated TEXT
      )
    ''');

    // Macro thresholds discovered by decision trees
    await db.execute('''
      CREATE TABLE macro_thresholds(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        macro_name TEXT,
        threshold_value REAL,
        symptom_type TEXT,
        risk_increase_pct REAL,
        baseline_rate REAL,
        elevated_rate REAL,
        sample_size INTEGER,
        confidence REAL,
        last_updated TEXT
      )
    ''');

    // ML feedback for user validation of predictions
    await db.execute('''
      CREATE TABLE ml_feedback(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        meal_assessment_id INTEGER,
        symptom_id INTEGER,
        predicted_risk REAL,
        predicted_severity REAL,
        actual_severity REAL,
        user_validation TEXT,
        outcome_match_score REAL,
        time_delta_minutes INTEGER,
        timestamp TEXT
      )
    ''');

    // Meal risk assessments shown to user
    await db.execute('''
      CREATE TABLE meal_assessments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        meal_id INTEGER,
        pain_risk REAL,
        diarrhea_risk REAL,
        bloating_risk REAL,
        top_factors TEXT,
        similar_meal_ids TEXT,
        confidence REAL,
        shown_at TEXT,
        user_acknowledged INTEGER DEFAULT 0
      )
    ''');

    // Weather cache for pressure change calculations
    await db.execute('''
      CREATE TABLE weather_cache(
        date TEXT PRIMARY KEY,
        temperature REAL,
        pressure REAL,
        condition TEXT,
        humidity REAL
      )
    ''');

    // Model calibration data
    await db.execute('''
      CREATE TABLE model_calibration(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        symptom_type TEXT,
        predicted_bin_start REAL,
        predicted_bin_end REAL,
        observed_frequency REAL,
        sample_size INTEGER,
        calibration_factor REAL,
        last_updated TEXT
      )
    ''');

    // Training history
    await db.execute('''
      CREATE TABLE training_history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        model_name TEXT,
        trained_at TEXT,
        sample_size INTEGER,
        accuracy REAL,
        precision_val REAL,
        recall_val REAL,
        f1_score REAL,
        feature_importances TEXT,
        validation_passed INTEGER
      )
    ''');

    print('[DB] ML tables created');
  }

  Future<void> _createFoodsTable(Database db) async {
    await db.execute('''
      CREATE TABLE foods(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        category TEXT,
        tags TEXT,
        barcode TEXT,
        brand TEXT,
        imageUrl TEXT,
        energy REAL,
        proteins REAL,
        fats REAL,
        carbs REAL,
        fiber REAL,
        sugars REAL,
        nutriScore TEXT,
        novaGroup INTEGER,
        allergens TEXT,
        servingSize REAL DEFAULT 100.0,
        isBasicFood INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('[DB] Upgrading from $oldVersion to $newVersion');

    if (oldVersion < 2) {
      await db.execute('ALTER TABLE events ADD COLUMN imagePath TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE events ADD COLUMN meta_data TEXT');
      await _createFoodsTable(db);
      await _seedBasicFoods(db);
    }
    if (oldVersion < 4) {
      // Complete reset for v4: delete old meals and foods
      await db.execute('DELETE FROM foods');
      await db.execute("DELETE FROM events WHERE type='meal'");

      // Add new columns to foods table
      await db.execute('ALTER TABLE foods ADD COLUMN barcode TEXT');
      await db.execute('ALTER TABLE foods ADD COLUMN brand TEXT');
      await db.execute('ALTER TABLE foods ADD COLUMN imageUrl TEXT');
      await db.execute('ALTER TABLE foods ADD COLUMN energy REAL');
      await db.execute('ALTER TABLE foods ADD COLUMN proteins REAL');
      await db.execute('ALTER TABLE foods ADD COLUMN fats REAL');
      await db.execute('ALTER TABLE foods ADD COLUMN carbs REAL');
      await db.execute('ALTER TABLE foods ADD COLUMN fiber REAL');
      await db.execute('ALTER TABLE foods ADD COLUMN sugars REAL');
      await db.execute('ALTER TABLE foods ADD COLUMN nutriScore TEXT');
      await db.execute('ALTER TABLE foods ADD COLUMN novaGroup INTEGER');
      await db.execute('ALTER TABLE foods ADD COLUMN allergens TEXT');
      await db.execute(
        'ALTER TABLE foods ADD COLUMN servingSize REAL DEFAULT 100.0',
      );
      await db.execute(
        'ALTER TABLE foods ADD COLUMN isBasicFood INTEGER DEFAULT 0',
      );

      // Create products cache table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS products_cache(
          barcode TEXT PRIMARY KEY,
          foodData TEXT,
          timestamp INTEGER
        )
      ''');

      // Seed basic foods
      await _seedBasicFoods(db);
    }
    if (oldVersion < 5) {
      // Add context_data column to events
      await db.execute('ALTER TABLE events ADD COLUMN context_data TEXT');
      print('[DB] Added context_data column to events');
    }
    if (oldVersion < 6) {
      // Create all ML and analytics tables
      await _createMLTables(db);
      print('[DB] Created ML tables');
    }
    if (oldVersion < 7) {
      // Complete reset for new category system (Repas/En-cas/Boisson)
      print('[DB] Migrating to v7: New category and tag system');

      // Delete ALL old data
      await db.execute('DELETE FROM foods');
      await db.execute("DELETE FROM events WHERE type='meal'");

      // Reseed with new categorization
      await _seedBasicFoods(db);

      print('[DB] v7 migration complete');
    }
    if (oldVersion < 8) {
      // Add generic "Poisson" entry
      print('[DB] Adding generic Poisson entry to foods');
      await db.insert('foods', {
        'name': 'Poisson',
        'category': 'Protéine',
        'tags': jsonEncode(['Protéine']),
        'isBasicFood': 1,
      });
    }
    if (oldVersion < 9) {
      print('[DB] Migrating to v9: Updating with comprehensive generic food list');
      // Remove old basic foods to avoid duplicates/outdated ones
      await db.delete('foods', where: 'isBasicFood = ?', whereArgs: [1]);
      await _seedGenericFoods(db);
    }
  }

  Future<void> _seedGenericFoods(Database db) async {
    print('[DB] Seeding generic foods from generic_foods.dart...');
    Batch batch = db.batch();
    for (var food in genericFoods) {
      batch.insert(
        'foods', 
        food.toMap(), 
        conflictAlgorithm: ConflictAlgorithm.replace
      );
    }
    await batch.commit(noResult: true);
    print('[DB] Seeded ${genericFoods.length} generic foods.');
  }

  Future<void> _seedBasicFoods(Database db) async {
    print('[DB] Seeding 50+ basic foods into DB...');
    final List<FoodModel> basicFoods = [
      // === FRUITS === (Catégorie: En-cas)
      FoodModel(
        name: 'Pomme',
        category: 'En-cas',
        tags: ['Fruit', 'Glucides', 'Fibres'],
        isBasicFood: true,
      ),
      FoodModel(
        name: 'Banane',
        category: 'En-cas',
        tags: ['Fruit', 'Glucides'],
        isBasicFood: true,
      ),
      FoodModel(
        name: 'Orange',
        category: 'En-cas',
        tags: ['Fruit', 'Glucides', 'Fibres'],
        isBasicFood: true,
      ),
      FoodModel(
        name: 'Fraise',
        category: 'En-cas',
        tags: ['Fruit', 'Glucides'],
        isBasicFood: true,
      ),
      FoodModel(
        name: 'Raisin',
        category: 'En-cas',
        tags: ['Fruit', 'Glucides'],
        isBasicFood: true,
      ),
      FoodModel(
        name: 'Poire',
        category: 'En-cas',
        tags: ['Fruit', 'Glucides', 'Fibres'],
        isBasicFood: true,
      ),

      // === LÉGUMES === (Catégorie: Repas)
      FoodModel(
        name: 'Carotte',
        category: 'Repas',
        tags: ['Légume', 'Fibres', 'Glucides'],
        isBasicFood: true,
      ),
      FoodModel(
        name: 'Tomate',
        category: 'Repas',
        tags: ['Légume', 'Fibres'],
        isBasicFood: true,
      ),
      FoodModel(
        name: 'Salade verte',
        category: 'Repas',
        tags: ['Légume', 'Fibres'],
        isBasicFood: true,
      ),
      FoodModel(
        name: 'Concombre',
        category: 'Repas',
        tags: ['Légume', 'Fibres'],
        isBasicFood: true,
      ),
      FoodModel(
        name: 'Courgette',
        category: 'Repas',
        tags: ['Légume', 'Fibres'],
        isBasicFood: true,
      ),
      FoodModel(
        name: 'Chou',
        category: 'Repas',
        tags: ['Légume', 'Fibres', 'Gaz'],
        isBasicFood: true,
      ),
      FoodModel(
        name: 'Brocoli',
        category: 'Repas',
        tags: ['Légume', 'Fibres', 'Gaz'],
        isBasicFood: true,
      ),
      FoodModel(
        name: 'Haricots verts',
        category: 'Repas',
        tags: ['Légume', 'Fibres'],
        isBasicFood: true,
      ),

      // === FÉCULENTS === (Catégorie: Repas)
      FoodModel(
        name: 'Riz blanc',
        category: 'Repas',
        tags: ['Féculent', 'Glucides'],
        isBasicFood: true,
      ),
      FoodModel(
        name: 'Pâtes',
        category: 'Repas',
        tags: ['Féculent', 'Glucides', 'Gluten'],
        isBasicFood: true,
      ),
      FoodModel(
        name: 'Pain',
        category: 'Repas',
        tags: ['Féculent', 'Glucides', 'Gluten'],
        isBasicFood: true,
      ),
      FoodModel(
        name: 'Pomme de terre',
        category: 'Repas',
        tags: ['Féculent', 'Glucides'],
        isBasicFood: true,
      ),
      FoodModel(
        name: 'Quinoa',
        category: 'Repas',
        tags: ['Féculent', 'Glucides', 'Protéine'],
        isBasicFood: true,
      ),

      // === PROTÉINES === (Catégorie: Repas)
      FoodModel(
        name: 'Poulet',
        category: 'Repas',
        tags: ['Protéine', 'Lipides'],
        isBasicFood: true,
      ),
      FoodModel(
        name: 'Dinde',
        category: 'Repas',
        tags: ['Protéine'],
        isBasicFood: true,
      ),
      FoodModel(
        name: 'Bœuf',
        category: 'Repas',
        tags: ['Protéine', 'Lipides', 'Gras'],
        isBasicFood: true,
      ),
      FoodModel(
        name: 'Porc',
        category: 'Repas',
        tags: ['Protéine', 'Lipides', 'Gras'],
        isBasicFood: true,
      ),
      FoodModel(
        name: 'Saumon',
        category: 'Repas',
        tags: ['Protéine', 'Lipides'],
        isBasicFood: true,
      ),
      FoodModel(
        name: 'Thon',
        category: 'Repas',
        tags: ['Protéine'],
        isBasicFood: true,
      ),
      FoodModel(
        name: 'Poisson',
        category: 'Protéine',
        tags: ['Protéine'],
        isBasicFood: true,
      ),
      FoodModel(
        name: 'Oeufs',
        category: 'Repas',
        tags: ['Protéine', 'Lipides'],
        isBasicFood: true,
      ),
      FoodModel(
        name: 'Jambon',
        category: 'Repas',
        tags: ['Protéine', 'Lipides', 'Gras'],
        isBasicFood: true,
      ),
      FoodModel(
        name: 'Saucisson',
        category: 'En-cas',
        tags: ['Protéine', 'Lipides', 'Gras'],
        isBasicFood: true,
      ),

      // === LAITAGES === (Catégorie: Repas/En-cas)
      FoodModel(
        name: 'Yaourt',
        category: 'En-cas',
        tags: ['Protéine', 'Lactose', 'Glucides'],
        isBasicFood: true,
      ),
      FoodModel(
        name: 'Fromage',
        category: 'Repas',
        tags: ['Protéine', 'Lipides', 'Gras', 'Lactose'],
        isBasicFood: true,
      ),
      FoodModel(
        name: 'Lait',
        category: 'Boisson',
        tags: ['Protéine', 'Lactose', 'Glucides'],
        isBasicFood: true,
      ),

      // === MATIÈRES GRASSES ===
      FoodModel(
        name: 'Huile Olive',
        category: 'Repas',
        tags: ['Lipides'],
        isBasicFood: true,
      ),
      FoodModel(
        name: 'Beurre',
        category: 'Repas',
        tags: ['Lipides', 'Gras', 'Lactose'],
        isBasicFood: true,
      ),

      // === SNACKS TRANSFORMÉS ===
      FoodModel(
        name: 'Chips',
        category: 'En-cas',
        tags: ['Glucides', 'Lipides', 'Gras'],
        isBasicFood: true,
      ),
      FoodModel(
        name: 'Biscuits',
        category: 'En-cas',
        tags: ['Glucides', 'Lipides', 'Gluten'],
        isBasicFood: true,
      ),
      FoodModel(
        name: 'Chocolat',
        category: 'En-cas',
        tags: ['Glucides', 'Lipides'],
        isBasicFood: true,
      ),

      // === PLATS COMPOSÉS ===
      FoodModel(
        name: 'Pizza',
        category: 'Repas',
        tags: ['Glucides', 'Protéine', 'Lipides', 'Gluten', 'Lactose', 'Gras'],
        isBasicFood: true,
      ),
      FoodModel(
        name: 'Burger',
        category: 'Repas',
        tags: ['Glucides', 'Protéine', 'Lipides', 'Gluten', 'Gras'],
        isBasicFood: true,
      ),
      FoodModel(
        name: 'Frites',
        category: 'Repas',
        tags: ['Glucides', 'Lipides', 'Gras'],
        isBasicFood: true,
      ),
      FoodModel(
        name: 'Curry',
        category: 'Repas',
        tags: ['Protéine', 'Lipides', 'Épicé', 'Gras'],
        isBasicFood: true,
      ),

      // === BOISSONS SANS ALCOOL ===
      FoodModel(name: 'Eau', category: 'Boisson', tags: [], isBasicFood: true),
      FoodModel(name: 'Café', category: 'Boisson', tags: [], isBasicFood: true),
      FoodModel(
        name: 'Thé',
        category: 'Boisson',
        tags: ['Caféine'],
        isBasicFood: true,
      ),

      // Autres
      FoodModel(
        name: 'Huile d\'olive',
        category: 'Snack',
        tags: ['Gras'],
        isBasicFood: true,
      ),
      FoodModel(
        name: 'Beurre',
        category: 'Snack',
        tags: ['Gras', 'Lactose'],
        isBasicFood: true,
      ),
    ];

    Batch batch = db.batch();
    for (var food in basicFoods) {
      batch.insert(
        'foods',
        food.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    final results = await batch.commit();
    print(
      '[DB] ${basicFoods.length} basic foods inserted successfully (${results.length} operations)',
    );
  }

  // Clean cache older than 90 days
  Future<void> cleanOldCache([Database? db]) async {
    db ??= await database;
    int cutoff = DateTime.now()
        .subtract(const Duration(days: 90))
        .millisecondsSinceEpoch;
    await db.delete(
      'products_cache',
      where: 'timestamp < ?',
      whereArgs: [cutoff],
    );
  }

  /// Enrich local foods database with popular OFF products
  /// This provides realistic demo data and better autocomplete
  Future<void> enrichWithPopularOFFProducts() async {
    print('[DB] 🌟 Enriching local DB with popular OFF products...');

    // Import OFFService - only import here to avoid circular dependency
    final offService = OFFService();

    // List of common French food barcodes from OpenFoodFacts
    // Diversified: breakfast, lunch/dinner, snacks, drinks
    final popularBarcodes = [
      // Breakfast items
      '3017620422003', // Nutella
      '3270190127512', // Confiture de fraises Carrefour BIO
      '3229820129488', // Muesli Raisin Figue Abricot Bjorg
      '3228857000906', // Pain AMS complet Harrys
      '8712566451555', // Café Nespresso Volluto
      // Lunch/Dinner - Proteins
      '3760074380282', // Poulet rôti
      '3250391807802', // Jambon Blanc Fleury Michon
      '3250391616664', // Saumon fumé Atlantique
      '3760091720207', // Steak haché 5% Charal
      // Lunch/Dinner - Starches
      '3560071484477', // Pâtes penne Panzani
      '3560070462827', // Riz basmati Uncle Ben's
      '8076809513821', // Pâtes Barilla Fusilli
      // Vegetables & Sides
      '3560070734016', // Tomates pelées en dés
      '3083680085403', // Pommes de terre
      '3250391618583', // Légumes pour couscous
      // Dairy
      '3228857000906', // Beurre Président
      '3270160311309', // Emmental râpé
      '3250391675494', // Yaourt nature Activia
      // Drinks
      '3073780970037', // Coca-Cola 33cl
      '3560070342099', // Lait demi-écrémé Lactel
      '5449000000996', // Eau Evian 1.5L
      // Snacks
      '7622210449283', // Prince goût chocolat
      '3017620422003', // Kinder Bueno
      '3222475787706', // Compote pomme Andros
    ];

    int successCount = 0;
    for (final barcode in popularBarcodes) {
      try {
        final product = await offService.fetchByBarcode(barcode);
        if (product != null) {
          await insertOrUpdateFood(product);
          successCount++;
        }
        // Delay to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        print('[DB] ⚠️ Failed to fetch barcode $barcode: $e');
      }
    }

    print(
      '[DB] ✅ Enriched local DB with $successCount/${popularBarcodes.length} OFF products',
    );
  }

  Future<int> insertFood(FoodModel food) async {
    Database db = await database;
    return await db.insert('foods', food.toMap());
  }

  /// Insert or update food if it already exists (by barcode or exact name)
  /// Returns true if inserted/updated, false if already existed unchanged
  Future<bool> insertOrUpdateFood(FoodModel food) async {
    Database db = await database;

    // Check if food already exists by barcode (if available) or exact name
    List<Map<String, dynamic>> existing;
    if (food.barcode != null && food.barcode!.isNotEmpty) {
      existing = await db.query(
        'foods',
        where: 'barcode = ?',
        whereArgs: [food.barcode],
        limit: 1,
      );
    } else {
      existing = await db.query(
        'foods',
        where: 'LOWER(name) = ?',
        whereArgs: [food.name.toLowerCase()],
        limit: 1,
      );
    }

    if (existing.isEmpty) {
      // Insert new food
      await db.insert('foods', food.toMap());
      print('[DB] ✅ Added new food to local DB: ${food.name}');
      return true;
    } else {
      // Update existing food with new data (e.g., updated nutrition info)
      final existingId = existing.first['id'];
      final updateMap = Map<String, dynamic>.from(food.toMap());
      updateMap.remove('id'); // Remove id field to avoid NULL constraint error
      await db.update(
        'foods',
        updateMap,
        where: 'id = ?',
        whereArgs: [existingId],
      );
      print('[DB] 🔄 Updated existing food: ${food.name}');
      return true;
    }
  }

  Future<List<FoodModel>> searchFoods(String query) async {
    print('[DB] Searching foods with query: "${query}"');
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'foods',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'isBasicFood DESC, length(name) ASC', 
      limit: 20,
    );
    print('[DB] Found ${maps.length} results for "${query}"');
    return List.generate(maps.length, (i) {
      return FoodModel.fromMap(maps[i]);
    });
  }

  Future<List<FoodModel>> getAllFoods() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'foods',
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) {
      return FoodModel.fromMap(maps[i]);
    });
  }

  Future<void> generateDemoData() async {
    print('[DB] Starting realistic demo data generation (v9)...');
    
    Database db = await database;
    await db.delete('events');
    print('[DB] Deleted all existing events');

    final now = DateTime.now();
    Batch batch = db.batch();

    // 1. Load Generic Foods from DB
    final List<Map<String, dynamic>> foodMaps = await db.query(
      'foods',
      where: 'isBasicFood = 1',
    );
    final basicFoods = foodMaps.map((m) => FoodModel.fromMap(m)).toList();
    
    if (basicFoods.isEmpty) {
      print('[DB] ⚠️ No generic foods found! Seeding...');
      await _seedGenericFoods(db);
      // Reload
      final reloaded = await db.query('foods', where: 'isBasicFood = 1');
      basicFoods.addAll(reloaded.map((m) => FoodModel.fromMap(m)).toList());
    }

    // 2. Categorize Foods for Meal Construction
    final proteins = basicFoods.where((f) => f.tags.contains('Protéine')).toList();
    final carbs = basicFoods.where((f) => f.tags.contains('Féculent')).toList();
    final veggies = basicFoods.where((f) => f.tags.contains('Légume')).toList();
    final fruits = basicFoods.where((f) => f.tags.contains('Fruit')).toList();
    final dairy = basicFoods.where((f) => f.tags.contains('Laitage')).toList();
    final drinks = basicFoods.where((f) => f.category == 'Boisson').toList();
    final snacks = basicFoods.where((f) => f.category == 'En-cas').toList();

    // Helper to get random item
    FoodModel random(List<FoodModel> list) => list[DateTime.now().microsecond % list.length];
    
    // Helper to create meal
    Map<String, dynamic> createMeal(List<FoodModel> foods) {
      return {
        'foods': foods.map((f) => f.toMap()).toList(),
        'tags': foods.expand((f) => f.tags).toSet().toList(),
      };
    }

    // 3. User Profile Simulation (Sensitivities)
    // Let's simulate a user sensitive to Gluten and Spicy food
    final sensitiveToGluten = true;
    final sensitiveToSpicy = true;
    
    // 4. Generate 60 Days of Data
    for (int i = 60; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      
      // Weather Context (Simplified random)
      final temp = 15.0 + (i % 10);
      final weatherContext = jsonEncode({
        'temperature': temp.toStringAsFixed(1),
        'pressure': (1013 - (i % 5)).toStringAsFixed(1),
        'weather': (i % 7 == 0) ? 'rainy' : 'sunny'
      });

      // === BREAKFAST (8:00) ===
      final breakfastFoods = [
        random(drinks), // Coffee/Tea
        random(carbs.where((f) => f.name.contains('Pain') || f.name.contains('Avoine')).toList()),
        (i % 2 == 0) ? random(dairy) : random(fruits),
      ];
      final bMeal = createMeal(breakfastFoods);
      
      batch.insert('events', {
        'type': 'meal',
        'dateTime': DateTime(date.year, date.month, date.day, 8, 0).toIso8601String(),
        'title': 'Petit-déjeuner',
        'subtitle': breakfastFoods.map((f) => f.name).join(', '),
        'severity': 0,
        'tags': (bMeal['tags'] as List).join(','),
        'meta_data': jsonEncode({'foods': bMeal['foods'], 'is_snack': false}),
        'context_data': weatherContext,
        'isUrgent': 0, 'isSnack': 0,
      });

      // === LUNCH (12:30) ===
      final lunchFoods = [
        random(proteins),
        random(carbs),
        random(veggies),
      ];
      // Randomly add a dessert
      if (i % 3 == 0) lunchFoods.add(random(fruits));
      
      final lMeal = createMeal(lunchFoods);
      batch.insert('events', {
        'type': 'meal',
        'dateTime': DateTime(date.year, date.month, date.day, 12, 30).toIso8601String(),
        'title': 'Déjeuner',
        'subtitle': lunchFoods.map((f) => f.name).join(', '),
        'severity': 0,
        'tags': (lMeal['tags'] as List).join(','),
        'meta_data': jsonEncode({'foods': lMeal['foods'], 'is_snack': false}),
        'context_data': weatherContext,
        'isUrgent': 0, 'isSnack': 0,
      });

      // === DINNER (19:30) ===
      // Dinner is lighter: often just soup or veggies + protein
      final dinnerFoods = [
        random(proteins),
        (i % 5 == 0) ? random(carbs) : random(veggies), // Less carbs at night
      ];
      final dMeal = createMeal(dinnerFoods);
      
      batch.insert('events', {
        'type': 'meal',
        'dateTime': DateTime(date.year, date.month, date.day, 19, 30).toIso8601String(),
        'title': 'Dîner',
        'subtitle': dinnerFoods.map((f) => f.name).join(', '),
        'severity': 0,
        'tags': (dMeal['tags'] as List).join(','),
        'meta_data': jsonEncode({'foods': dMeal['foods'], 'is_snack': false}),
        'context_data': weatherContext,
        'isUrgent': 0, 'isSnack': 0,
      });

      // === SNACK (16:00) - Occasional ===
      if (i % 2 == 0) {
        final snackFoods = [random(snacks)];
        final sMeal = createMeal(snackFoods);
        batch.insert('events', {
          'type': 'meal',
          'dateTime': DateTime(date.year, date.month, date.day, 16, 0).toIso8601String(),
          'title': 'Goûter',
          'subtitle': snackFoods[0].name,
          'severity': 0,
          'tags': (sMeal['tags'] as List).join(','),
          'meta_data': jsonEncode({'foods': sMeal['foods'], 'is_snack': true}),
          'context_data': weatherContext,
          'isUrgent': 0, 'isSnack': 1,
        });
      }

      // === SYMPTOM GENERATION LOGIC ===
      // Check triggers from today's meals
      bool triggerGluten = false;
      bool triggerSpicy = false;
      bool triggerFibers = false;

      final todaysMeals = [bMeal, lMeal, dMeal];
      for (var meal in todaysMeals) {
        final tags = (meal['tags'] as List).map((t) => t.toString()).toList();
        if (sensitiveToGluten && tags.contains('Gluten')) triggerGluten = true;
        if (sensitiveToSpicy && tags.contains('Épicé')) triggerSpicy = true;
        // Assume high fiber if lots of veggies/fruits
        if (tags.where((t) => t == 'Fibres').length >= 2) triggerFibers = true;
      }

      // Reaction: 2-4 hours after meal (simplified to afternoon/evening/next morning)
      
      if (triggerGluten && (i % 3 != 0)) { // 66% chance of reaction
        batch.insert('events', {
          'type': 'symptom',
          'dateTime': DateTime(date.year, date.month, date.day, 14, 30).toIso8601String(),
          'title': 'Ballonnement',
          'subtitle': 'Post-repas',
          'severity': 4 + (i % 3),
          'tags': 'Gaz,Digestion',
          'context_data': weatherContext,
          'isUrgent': 0, 'isSnack': 0,
        });
      }

      if (triggerSpicy && (i % 2 == 0)) { // 50% chance
        batch.insert('events', {
          'type': 'symptom',
          'dateTime': DateTime(date.year, date.month, date.day, 21, 0).toIso8601String(),
          'title': 'Brûlures d\'estomac',
          'subtitle': 'Acide',
          'severity': 6,
          'tags': 'Inflammation',
          'context_data': weatherContext,
          'isUrgent': 0, 'isSnack': 0,
        });
      }

      // Random good/bad days independent of food (Flare-ups)
      if (i == 10 || i == 11 || i == 12) { // A 3-day flare up
         batch.insert('events', {
          'type': 'symptom',
          'dateTime': DateTime(date.year, date.month, date.day, 10, 0).toIso8601String(),
          'title': 'Douleur Abdominale',
          'subtitle': 'Crise',
          'severity': 8,
          'tags': 'Inflammation,Général',
          'context_data': weatherContext,
          'isUrgent': 1, 'isSnack': 0,
        });
        
        // Diarrhea during flare
        batch.insert('events', {
          'type': 'stool',
          'dateTime': DateTime(date.year, date.month, date.day, 11, 0).toIso8601String(),
          'title': 'Type 7',
          'subtitle': 'Eau',
          'severity': 0,
          'tags': 'Urgent,Sang',
          'context_data': weatherContext,
          'isUrgent': 1, 'isSnack': 0,
        });
      }

      // Daily Stool (Morning) - Normal if no flare
      if (i != 10 && i != 11 && i != 12) {
        batch.insert('events', {
          'type': 'stool',
          'dateTime': DateTime(date.year, date.month, date.day, 8, 30).toIso8601String(),
          'title': 'Type 4',
          'subtitle': 'Normal',
          'severity': 0,
          'tags': 'Normal',
          'context_data': weatherContext,
          'isUrgent': 0, 'isSnack': 0,
        });
      }
    }

    await batch.commit();
    print('[DB] Generated 60 days of realistic demo data based on Generic Foods.');
  }

  // --- Analysis Helpers ---
  Future<Map<String, int>> getSymptomZones(int days) async {
    Database db = await database;
    // Get all symptom events
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days)).toIso8601String();

    final res = await db.query(
      'events',
      columns: ['title'],
      where: "type = ? AND dateTime >= ?",
      whereArgs: ['symptom', start],
    );

    Map<String, int> counts = {};
    for (var row in res) {
      String t = row['title'] as String;
      // Basic filter to avoid counting "Generic" titles if strictly zones wanted
      // But here we count everything labeled as a symptom title
      counts[t] = (counts[t] ?? 0) + 1;
    }
    return counts;
  }

  // Example method to insert event (generic helper)
  Future<int> insertEvent(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert('events', row);
  }

  // Delete event by ID
  Future<int> deleteEvent(int id) async {
    Database db = await database;
    return await db.delete('events', where: 'id = ?', whereArgs: [id]);
  }

  // Update event by ID
  Future<int> updateEvent(int id, Map<String, dynamic> data) async {
    Database db = await database;
    print('[DB] Updating event $id with data: $data');
    // Remove id field to avoid NULL constraint error
    final updateData = Map<String, dynamic>.from(data);
    updateData.remove('id');
    return await db.update(
      'events',
      updateData,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Example method to get all events
  Future<List<Map<String, dynamic>>> getEvents() async {
    Database db = await database;
    return await db.query('events', orderBy: 'dateTime DESC');
  }

  // --- Statistics Queries ---

  // Get daily max pain for the last X days
  Future<List<Map<String, dynamic>>> getPainEvolution(int days) async {
    Database db = await database;
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days)).toIso8601String();

    // We want one point per day (Max severity)
    // SQLite doesn't have easy date grouping, so we do string manipulation on dateTime
    return await db.rawQuery(
      '''
      SELECT substr(dateTime, 1, 10) as date, MAX(severity) as max_severity
      FROM events
      WHERE type = 'symptom' AND dateTime >= ?
      GROUP BY substr(dateTime, 1, 10)
      ORDER BY date ASC
    ''',
      [startDate],
    );
  }

  // Get stool count per day for the last X days
  Future<List<Map<String, dynamic>>> getStoolFrequency(int days) async {
    Database db = await database;
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days)).toIso8601String();

    // Group by date, count entries, and average Bristol type (if stored clearly, but here we count)
    // We can try to extract Bristol type from title "Type X" if needed, but for now just count.
    return await db.rawQuery(
      '''
      SELECT substr(dateTime, 1, 10) as date, COUNT(*) as count
      FROM events
      WHERE type = 'stool' AND dateTime >= ?
      GROUP BY substr(dateTime, 1, 10)
      ORDER BY date ASC
    ''',
      [startDate],
    );
  }

  // Get last 3 meals before a specific date (or just last meals overall if date not provided)
  Future<List<Map<String, dynamic>>> getLastMeals(
    int limit, {
    String? beforeDate,
  }) async {
    Database db = await database;
    String whereClause = "type = 'meal'";
    List<dynamic> args = [];

    if (beforeDate != null) {
      whereClause += " AND dateTime < ?";
      args.add(beforeDate);
    }

    return await db.query(
      'events',
      where: whereClause,
      whereArgs: args,
      orderBy: 'dateTime DESC',
      limit: limit,
    );
  }

  // === ML AND ANALYTICS QUERIES ===

  /// Get meal-symptom pairs within a time window
  /// Returns meals with their subsequent symptoms (if any) within specified hours
  Future<List<Map<String, dynamic>>> getMealSymptomPairs(
    int windowHours,
  ) async {
    Database db = await database;

    // Get all meals with their context
    final meals = await db.query(
      'events',
      where: "type = 'meal'",
      orderBy: 'dateTime DESC',
    );

    final pairs = <Map<String, dynamic>>[];

    for (final meal in meals) {
      final mealTime = DateTime.parse(meal['dateTime'] as String);
      final windowEnd = mealTime.add(Duration(hours: windowHours));

      // Find symptoms within window
      final symptoms = await db.query(
        'events',
        where: "type = 'symptom' AND dateTime > ? AND dateTime <= ?",
        whereArgs: [meal['dateTime'], windowEnd.toIso8601String()],
        orderBy: 'dateTime ASC',
        limit: 1, // Get first symptom in window
      );

      final pair = <String, dynamic>{
        'meal_id': meal['id'],
        'meal_time': meal['dateTime'],
        'tags': meal['tags'] ?? '',
        'meta_data': meal['meta_data'],
        'context_data': meal['context_data'],
      };

      if (symptoms.isNotEmpty) {
        final symptom = symptoms.first;
        final symptomTime = DateTime.parse(symptom['dateTime'] as String);
        final timeDelta = symptomTime.difference(mealTime);

        pair['symptom_id'] = symptom['id'];
        pair['symptom_time'] = symptom['dateTime'];
        pair['severity'] = symptom['severity'];
        pair['time_delta_minutes'] = timeDelta.inMinutes;
      } else {
        pair['symptom_id'] = null;
        pair['symptom_time'] = null;
        pair['severity'] = 0;
        pair['time_delta_minutes'] = null;
      }

      pairs.add(pair);
    }

    return pairs;
  }

  /// Get feature matrix for ML training
  /// Returns all events structured for export to CSV
  Future<List<Map<String, dynamic>>> getFeatureMatrix(int days) async {
    Database db = await database;
    final startDate = DateTime.now()
        .subtract(Duration(days: days))
        .toIso8601String();

    return await db.rawQuery(
      '''
      SELECT 
        e.*,
        (SELECT COUNT(*) FROM events WHERE type='meal' AND dateTime < e.dateTime AND date(dateTime) = date(e.dateTime)) as meals_today_count,
        (SELECT dateTime FROM events WHERE type='meal' AND dateTime < e.dateTime ORDER BY dateTime DESC LIMIT 1) as last_meal_time
      FROM events e
      WHERE e.dateTime >= ?
      ORDER BY e.dateTime ASC
    ''',
      [startDate],
    );
  }

  /// Get similar meals by feature similarity
  /// Returns meals with similar tags and nutrition profiles
  Future<List<Map<String, dynamic>>> getSimilarMeals(
    String tags,
    String? metaData, {
    int limit = 10,
  }) async {
    Database db = await database;

    // Simple tag-based similarity for now
    // In production, would use feature vectors and cosine similarity
    final tagList = tags.split(',').map((t) => t.trim()).toList();

    final meals = await db.query(
      'events',
      where: "type = 'meal'",
      orderBy: 'dateTime DESC',
      limit: 100, // Get recent meals
    );

    // Calculate similarity scores
    final scored = meals
        .map((meal) {
          final mealTags = (meal['tags'] as String? ?? '')
              .split(',')
              .map((t) => t.trim())
              .toList();

          // Count matching tags
          int matchCount = 0;
          for (final tag in tagList) {
            if (mealTags.contains(tag)) matchCount++;
          }

          final similarity = matchCount / max(tagList.length, mealTags.length);

          return {...meal, 'similarity': similarity};
        })
        .where((m) => (m['similarity'] as double) > 0.3)
        .toList();

    // Sort by similarity descending
    scored.sort(
      (a, b) =>
          (b['similarity'] as double).compareTo(a['similarity'] as double),
    );

    return scored.take(limit).toList();
  }

  /// Get average nutrition data over a date range
  Future<Map<String, double>> getAverageNutrition(
    DateTime startDate,
    DateTime endDate,
  ) async {
    Database db = await database;

    final meals = await db.query(
      'events',
      where: "type = 'meal' AND dateTime >= ? AND dateTime <= ?",
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
    );

    if (meals.isEmpty) {
      return {
        'proteins': 0.0,
        'fats': 0.0,
        'carbs': 0.0,
        'fiber': 0.0,
        'sugars': 0.0,
        'energy': 0.0,
      };
    }

    double totalProteins = 0.0;
    double totalFats = 0.0;
    double totalCarbs = 0.0;
    double totalFiber = 0.0;
    double totalSugars = 0.0;
    double totalEnergy = 0.0;
    int count = 0;

    for (final meal in meals) {
      final metaData = meal['meta_data'] as String?;
      if (metaData == null || metaData.isEmpty) continue;

      // Parse nutrition from metadata
      // This is simplified - in production would use proper JSON parsing
      if (metaData.contains('proteins')) {
        final nutrition = _parseNutritionFromMetadata(metaData);
        totalProteins += nutrition['proteins'] ?? 0.0;
        totalFats += nutrition['fats'] ?? 0.0;
        totalCarbs += nutrition['carbs'] ?? 0.0;
        totalFiber += nutrition['fiber'] ?? 0.0;
        totalSugars += nutrition['sugars'] ?? 0.0;
        totalEnergy += nutrition['energy'] ?? 0.0;
        count++;
      }
    }

    if (count == 0) {
      return {
        'proteins': 0.0,
        'fats': 0.0,
        'carbs': 0.0,
        'fiber': 0.0,
        'sugars': 0.0,
        'energy': 0.0,
      };
    }

    return {
      'proteins': totalProteins / count,
      'fats': totalFats / count,
      'carbs': totalCarbs / count,
      'fiber': totalFiber / count,
      'sugars': totalSugars / count,
      'energy': totalEnergy / count,
    };
  }

  /// Parse nutrition data from metadata JSON (simplified)
  Map<String, double> _parseNutritionFromMetadata(String metaData) {
    final nutrition = <String, double>{};

    // Very simplified regex-based extraction
    // In production, use proper JSON parsing
    final patterns = {
      'proteins': RegExp(r'"proteins":([\d.]+)'),
      'fats': RegExp(r'"fats":([\d.]+)'),
      'carbs': RegExp(r'"carbs":([\d.]+)'),
      'fiber': RegExp(r'"fiber":([\d.]+)'),
      'sugars': RegExp(r'"sugars":([\d.]+)'),
      'energy': RegExp(r'"energy":([\d.]+)'),
    };

    for (final entry in patterns.entries) {
      final match = entry.value.firstMatch(metaData);
      if (match != null) {
        nutrition[entry.key] = double.tryParse(match.group(1)!) ?? 0.0;
      } else {
        nutrition[entry.key] = 0.0;
      }
    }

    return nutrition;
  }

  /// Check if we have sufficient data for ML training
  Future<TrainingDataStatus> checkTrainingDataAvailability() async {
    final db = await database;

    // Count meals in last 90 days
    final mealResult = await db.rawQuery("""
      SELECT COUNT(*) as count
      FROM events
      WHERE type = 'meal'
      AND dateTime >= datetime('now', '-90 days')
    """);

    final mealCount = mealResult.first['count'] as int;

    // Count symptoms in last 90 days
    final symptomResult = await db.rawQuery("""
      SELECT COUNT(*) as count
      FROM events
      WHERE type = 'symptom'
      AND dateTime >= datetime('now', '-90 days')
    """);

    final symptomCount = symptomResult.first['count'] as int;

    final hasEnoughData = mealCount >= 30 && symptomCount >= 10;

    final message = hasEnoughData
        ? 'Ready to train: $mealCount meals, $symptomCount symptoms'
        : 'Need 30+ meals and 10+ symptoms (have: $mealCount meals, $symptomCount symptoms)';

    print('[DB] Training data check: $message');

    return TrainingDataStatus(
      mealCount: mealCount,
      symptomCount: symptomCount,
      hasEnoughData: hasEnoughData,
      message: message,
    );
  }

  /// Check training data availability by symptom type
  /// Returns detailed status for each model type including correlation counts
  Future<Map<String, Map<String, dynamic>>> checkTrainingDataByType() async {
    final db = await database;
    final statusByType = <String, Map<String, dynamic>>{};

    print('[DB] Checking training data by symptom type...');

    // Import symptom taxonomy mappings
    final symptomMappings = {
      'pain': 'Inflammation',
      'diarrhea': 'Urgent',
      'bloating': 'Gaz',
      'joints': 'Articulations',
      'skin': 'Peau',
      'oral': 'Bouche/ORL',
      'systemic': 'Général',
    };

    for (final entry in symptomMappings.entries) {
      final modelKey = entry.key;
      final frenchTag = entry.value;

      // Count symptoms with this tag (90-day window)
      final symptomResult = await db.rawQuery(
        """
        SELECT COUNT(*) as count
        FROM events
        WHERE type = 'symptom'
        AND tags LIKE ?
        AND dateTime >= datetime('now', '-90 days')
      """,
        ['%$frenchTag%'],
      );

      final symptomCount = symptomResult.first['count'] as int;

      // Count meal-symptom correlations (4-8 hour window)
      final correlationResult = await db.rawQuery(
        """
        SELECT COUNT(*) as count
        FROM events m
        INNER JOIN events s ON (
          julianday(s.dateTime) - julianday(m.dateTime)
        ) * 24 BETWEEN 4 AND 8
        WHERE m.type = 'meal'
        AND s.type = 'symptom'
        AND s.tags LIKE ?
        AND m.dateTime >= datetime('now', '-90 days')
        AND s.dateTime >= datetime('now', '-90 days')
      """,
        ['%$frenchTag%'],
      );

      final correlationCount = correlationResult.first['count'] as int;

      // Count total meals (for context)
      final mealResult = await db.rawQuery("""
        SELECT COUNT(*) as count
        FROM events
        WHERE type = 'meal'
        AND dateTime >= datetime('now', '-90 days')
      """);

      final mealCount = mealResult.first['count'] as int;

      // Determine readiness
      final minSamples =
          (modelKey == 'pain' ||
              modelKey == 'diarrhea' ||
              modelKey == 'bloating')
          ? 30
          : 20;
      final isReady = mealCount >= 30 && correlationCount >= 5;

      statusByType[modelKey] = {
        'french_tag': frenchTag,
        'symptom_count': symptomCount,
        'correlation_count': correlationCount,
        'meal_count': mealCount,
        'min_samples': minSamples,
        'is_ready': isReady,
        'status': isReady ? 'ready' : 'insufficient_data',
      };

      print(
        '[DB]   $modelKey ($frenchTag): $symptomCount symptoms, $correlationCount correlations → ${isReady ? "ready" : "need more data"}',
      );
    }

    return statusByType;
  }

  /// Get suspect ingredients based on symptom correlation (90-day window)
  Future<List<Map<String, dynamic>>> getSuspectIngredients({
    double minCorrelation = 0.3,
  }) async {
    final db = await database;

    print('[DB] Analyzing suspect ingredients...');

    // Get all meals in last 90 days with their foods
    final mealsResult = await db.rawQuery("""
      SELECT id, dateTime, meta_data
      FROM events
      WHERE type = 'meal'
      AND dateTime >= datetime('now', '-90 days')
      ORDER BY dateTime DESC
    """);

    if (mealsResult.isEmpty) {
      return [];
    }

    // Count symptom occurrences within 4-8h after each food
    Map<String, int> foodSymptomCount = {};
    Map<String, int> foodTotalCount = {};

    for (final meal in mealsResult) {
      final metaData = meal['meta_data'] as String?;
      if (metaData == null || metaData.isEmpty) continue;

      try {
        final data = jsonDecode(metaData);
        final foods = data['foods'] as List?;
        if (foods == null) continue;

        // Check for symptoms 4-8 hours after this meal
        final symptomResult = await db.rawQuery(
          """
          SELECT COUNT(*) as count
          FROM events
          WHERE type = 'symptom'
          AND julianday(dateTime) - julianday(?) BETWEEN ${4.0 / 24} AND ${8.0 / 24}
        """,
          [meal['dateTime']],
        );

        final hasSymptom = (symptomResult.first['count'] as int) > 0;

        // Count each food
        for (final food in foods) {
          final foodName = food['name'] as String?;
          if (foodName == null) continue;

          foodTotalCount[foodName] = (foodTotalCount[foodName] ?? 0) + 1;
          if (hasSymptom) {
            foodSymptomCount[foodName] = (foodSymptomCount[foodName] ?? 0) + 1;
          }
        }
      } catch (e) {
        print('[DB] Error parsing meal $meal: $e');
        continue;
      }
    }

    // Calculate correlation ratios
    List<Map<String, dynamic>> suspects = [];

    for (final foodName in foodTotalCount.keys) {
      final total = foodTotalCount[foodName]!;
      final symptomOccurrences = foodSymptomCount[foodName] ?? 0;
      final ratio = symptomOccurrences / total;

      if (ratio >= minCorrelation && total >= 3) {
        suspects.add({
          'food_name': foodName,
          'symptom_count': symptomOccurrences,
          'total_count': total,
          'correlation_ratio': ratio,
        });
      }
    }

    // Sort by correlation ratio descending
    suspects.sort(
      (a, b) => (b['correlation_ratio'] as double).compareTo(
        a['correlation_ratio'] as double,
      ),
    );

    print(
      '[DB] Found ${suspects.length} suspect ingredients (min correlation: $minCorrelation)',
    );

    return suspects;
  }

  /// Get latest training history entries
  Future<List<Map<String, dynamic>>> getLatestTrainingHistory({
    int limit = 10,
  }) async {
    final db = await database;

    final result = await db.query(
      'training_history',
      orderBy: 'trained_at DESC',
      limit: limit,
    );

    return result;
  }

  /// Get weather correlation with symptoms
  Future<Map<String, dynamic>> getWeatherCorrelations() async {
    final db = await database;

    // Query symptoms with weather data from last 90 days
    final results = await db.rawQuery('''
      SELECT 
        json_extract(context_data, '\$.weather_condition') as weather,
        CAST(json_extract(context_data, '\$.pressure_hpa') as REAL) as pressure,
        CAST(json_extract(context_data, '\$.temperature_celsius') as REAL) as temperature,
        CAST(json_extract(context_data, '\$.humidity') as REAL) as humidity,
        tags,
        COUNT(*) as symptom_count,
        AVG(severity) as avg_severity
      FROM events
      WHERE type = 'symptom' 
        AND context_data IS NOT NULL
        AND datetime(dateTime) >= datetime('now', '-90 days')
      GROUP BY weather, 
        CAST(json_extract(context_data, '\$.pressure_hpa') as INTEGER) / 10,
        tags
      HAVING symptom_count >= 2
      ORDER BY symptom_count DESC
    ''');

    // Analyze low pressure correlation
    final lowPressureSymptoms = results.where((r) {
      final pressure = r['pressure'];
      return pressure != null && pressure is num && pressure < 1010;
    }).toList();

    // Analyze rainy day correlation
    final rainyDaySymptoms = results.where((r) {
      final weather = r['weather'];
      return weather != null &&
          weather.toString().toLowerCase().contains('rain');
    }).toList();

    return {
      'all_patterns': results,
      'low_pressure_symptoms': lowPressureSymptoms,
      'rainy_day_symptoms': rainyDaySymptoms,
      'total_weather_events': results.length,
    };
  }

  int max(int a, int b) => a > b ? a : b;
}
