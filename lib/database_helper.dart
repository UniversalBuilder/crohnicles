import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'food_model.dart';
import 'services/off_service.dart';

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
      version: 8,
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

    print('[DB] Seeding basic foods...');
    await _seedBasicFoods(db);
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
    print('[DB] Searching foods with query: \"$query\"');
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'foods',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      limit: 20,
    );
    print('[DB] Found ${maps.length} results for \"$query\"');
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
    print('[DB] Starting demo data generation...');

    // First, enrich DB with real OFF products if not already done
    final allFoods = await getAllFoods();
    if (allFoods
            .where((f) => f.barcode != null && f.barcode!.isNotEmpty)
            .length <
        5) {
      print('[DB] Enriching DB with OFF products first...');
      await enrichWithPopularOFFProducts();
    }

    Database db = await database;
    await db.delete('events');
    print('[DB] Deleted all existing events');

    final now = DateTime.now();
    Batch batch = db.batch();

    // Get real foods from DB for realistic meals
    final availableFoods = await getAllFoods();
    final basicFoods = availableFoods.where((f) => f.barcode == null).toList();
    final offFoods = availableFoods.where((f) => f.barcode != null).toList();

    print(
      '[DB] Using ${basicFoods.length} basic foods + ${offFoods.length} OFF products',
    );

    // Listes pour l'aléatoire
    final List<String> painLocations = [
      "Fosse Iliaque D.",
      "Hypogastre",
      "Ombilic",
      "Flanc Gauche",
      "Épigastre",
    ];

    // Helper to create meal with real foods
    Map<String, dynamic> createMealFromFoods(List<FoodModel> foods) {
      return {
        'foods': foods
            .map(
              (f) => {
                'name': f.name,
                'category': f.category,
                'barcode': f.barcode,
                'brand': f.brand,
                'imageUrl': f.imageUrl,
                'proteins': f.proteins,
                'fats': f.fats,
                'carbs': f.carbs,
                'fiber': f.fiber,
                'sugars': f.sugars,
              },
            )
            .toList(),
        'tags': foods.expand((f) => f.tags).toSet().toList(),
      };
    }

    // Combine all available foods for meal generation
    final combinedFoods = [...basicFoods, ...offFoods];

    if (combinedFoods.isEmpty) {
      print('[DB] ⚠️ No foods available for demo generation!');
      return;
    }

    // Group foods by meal type based on category and tags
    final breakfastFoods = combinedFoods.where((f) {
      final cat = f.category.toLowerCase();
      final tags = f.tags.map((t) => t.toLowerCase()).toList();
      return cat.contains('petit') ||
          cat.contains('céréale') ||
          tags.any(
            (t) => [
              'confiture',
              'miel',
              'beurre',
              'croissant',
              'pain',
            ].contains(t.toLowerCase()),
          ) ||
          f.name.toLowerCase().contains('croissant') ||
          f.name.toLowerCase().contains('muesli') ||
          f.name.toLowerCase().contains('confiture') ||
          f.name.toLowerCase().contains('nutella') ||
          f.name.toLowerCase().contains('café') ||
          f.name.toLowerCase().contains('pain');
    }).toList();

    final lunchFoods = combinedFoods.where((f) {
      final cat = f.category.toLowerCase();
      final tags = f.tags.map((t) => t.toLowerCase()).toList();
      return cat.contains('plat') ||
          cat.contains('féculent') ||
          cat.contains('protéine') ||
          cat.contains('viande') ||
          tags.any(
            (t) => [
              'pâtes',
              'riz',
              'poulet',
              'poisson',
              'viande',
            ].contains(t.toLowerCase()),
          );
    }).toList();

    final dinnerFoods = combinedFoods.where((f) {
      final cat = f.category.toLowerCase();
      return cat.contains('plat') ||
          cat.contains('viande') ||
          cat.contains('légume') ||
          cat.contains('protéine');
    }).toList();

    final snackFoods = combinedFoods.where((f) {
      final cat = f.category.toLowerCase();
      return cat.contains('snack') ||
          cat.contains('fruit') ||
          cat.contains('yaourt') ||
          cat.contains('dessert') ||
          cat.contains('boisson');
    }).toList();

    // Create realistic breakfast meals
    final List<Map<String, dynamic>> breakfastMeals = [];
    if (breakfastFoods.length >= 2) {
      breakfastMeals.add(
        createMealFromFoods([breakfastFoods[0], breakfastFoods[1]]),
      );
      if (breakfastFoods.length >= 3) {
        breakfastMeals.add(
          createMealFromFoods([breakfastFoods[1], breakfastFoods[2]]),
        );
      }
    } else if (breakfastFoods.length == 1) {
      breakfastMeals.add(createMealFromFoods([breakfastFoods[0]]));
    } else if (combinedFoods.isNotEmpty) {
      // Fallback: use first 2 foods
      breakfastMeals.add(createMealFromFoods([combinedFoods[0]]));
    }

    // Create realistic lunch meals
    final List<Map<String, dynamic>> lunchMealsList = [];
    if (lunchFoods.length >= 2) {
      lunchMealsList.add(createMealFromFoods([lunchFoods[0], lunchFoods[1]]));
      if (lunchFoods.length >= 3) {
        lunchMealsList.add(createMealFromFoods([lunchFoods[1], lunchFoods[2]]));
      }
    } else if (lunchFoods.length == 1) {
      lunchMealsList.add(createMealFromFoods([lunchFoods[0]]));
    } else if (combinedFoods.length >= 2) {
      // Fallback: use any foods
      lunchMealsList.add(
        createMealFromFoods([combinedFoods[0], combinedFoods[1]]),
      );
    }

    // Create realistic dinner meals
    final List<Map<String, dynamic>> dinnerMealsList = [];
    if (dinnerFoods.length >= 2) {
      dinnerMealsList.add(
        createMealFromFoods([dinnerFoods[0], dinnerFoods[1]]),
      );
      if (dinnerFoods.length >= 3) {
        dinnerMealsList.add(
          createMealFromFoods([dinnerFoods[1], dinnerFoods[2]]),
        );
      }
    } else if (dinnerFoods.length == 1) {
      dinnerMealsList.add(createMealFromFoods([dinnerFoods[0]]));
    } else if (combinedFoods.length >= 2) {
      dinnerMealsList.add(
        createMealFromFoods([combinedFoods[0], combinedFoods[1]]),
      );
    }

    // Create snack meals
    final List<Map<String, dynamic>> snackMealsList = [];
    if (snackFoods.isNotEmpty) {
      snackMealsList.add(createMealFromFoods([snackFoods[0]]));
      if (snackFoods.length >= 2) {
        snackMealsList.add(createMealFromFoods([snackFoods[1]]));
      }
    }

    // Trigger meals (riskier combinations - can reuse any category)
    final List<Map<String, dynamic>> triggerMeals = [];
    if (snackFoods.length >= 2) {
      // Trigger: high-sugar or high-fat snacks
      triggerMeals.add(createMealFromFoods([snackFoods[0], snackFoods[1]]));
    } else if (combinedFoods.length >= 2) {
      triggerMeals.add(
        createMealFromFoods([combinedFoods[0], combinedFoods[1]]),
      );
    }

    // Fallback: ensure we have at least one meal for each category
    if (breakfastMeals.isEmpty && combinedFoods.isNotEmpty) {
      breakfastMeals.add(createMealFromFoods([combinedFoods[0]]));
    }
    if (lunchMealsList.isEmpty && combinedFoods.isNotEmpty) {
      lunchMealsList.add(createMealFromFoods([combinedFoods[0]]));
    }
    if (dinnerMealsList.isEmpty && combinedFoods.isNotEmpty) {
      dinnerMealsList.add(createMealFromFoods([combinedFoods[0]]));
    }
    if (triggerMeals.isEmpty && combinedFoods.isNotEmpty) {
      triggerMeals.add(createMealFromFoods([combinedFoods[0]]));
    }

    if (breakfastMeals.isEmpty ||
        lunchMealsList.isEmpty ||
        dinnerMealsList.isEmpty) {
      print('[DB] ⚠️ Could not create meals from available foods!');
      return;
    }

    // Simulation state
    int daysUntilCrisis = 0; // Countdown
    bool inCrisis = false;

    for (int i = 30; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final weekDay = date.weekday;

      // Determine if today is a "Risk" day (Friday/Saturday)
      bool riskDay = (weekDay == 5 || weekDay == 6);

      // -- MEALS --
      // Breakfast (7h-9h)
      final breakfast = breakfastMeals[i % breakfastMeals.length];
      final breakfastFoodsList = breakfast['foods'] as List;
      final breakfastTags = (breakfast['tags'] as List<dynamic>).join(',');
      final breakfastTitle = breakfastFoodsList
          .map((f) => f['name'])
          .join(' + ');

      batch.insert('events', {
        'type': 'meal',
        'dateTime': DateTime(
          date.year,
          date.month,
          date.day,
          8,
          0,
        ).toIso8601String(),
        'title': breakfastTitle,
        'subtitle': 'Maison',
        'severity': 0,
        'tags': breakfastTags,
        'meta_data': jsonEncode({'foods': breakfastFoodsList}),
        'isUrgent': 0,
        'isSnack': 0,
      });

      // Lunch is usually okay
      final lunch = lunchMealsList[i % lunchMealsList.length];
      final lunchFoods = lunch['foods'] as List;
      final lunchTags = (lunch['tags'] as List<dynamic>).join(',');
      final lunchTitle = lunchFoods.map((f) => f['name']).join(' + ');

      batch.insert('events', {
        'type': 'meal',
        'dateTime': DateTime(
          date.year,
          date.month,
          date.day,
          12,
          30,
        ).toIso8601String(),
        'title': lunchTitle,
        'subtitle': 'Maison',
        'severity': 0,
        'tags': lunchTags,
        'meta_data': jsonEncode({'foods': lunchFoods}),
        'isUrgent': 0,
        'isSnack': 0,
      });

      // Dinner
      if (riskDay) {
        // Trigger Food!
        // Sauf si on est déjà en crise, auquel cas on mange léger
        if (inCrisis) {
          batch.insert('events', {
            'type': 'meal',
            'dateTime': DateTime(
              date.year,
              date.month,
              date.day,
              20,
              0,
            ).toIso8601String(),
            'title': 'Bouillon',
            'subtitle': 'Diète',
            'severity': 0,
            'tags': 'Liquide,Sel',
            'meta_data': jsonEncode({
              'foods': [
                {'name': 'Bouillon', 'category': 'Plat'},
              ],
            }),
            'isUrgent': 0,
            'isSnack': 0,
          });
        } else {
          final trigger = triggerMeals[i % triggerMeals.length];
          final triggerFoods = trigger['foods'] as List<Map<String, dynamic>>;
          final triggerTags = (trigger['tags'] as List<dynamic>).join(',');
          final triggerTitle = triggerFoods.map((f) => f['name']).join(' + ');

          batch.insert('events', {
            'type': 'meal',
            'dateTime': DateTime(
              date.year,
              date.month,
              date.day,
              20,
              0,
            ).toIso8601String(),
            'title': triggerTitle,
            'subtitle': 'Sortie',
            'severity': 0,
            'tags': triggerTags,
            'meta_data': jsonEncode({'foods': triggerFoods}),
            'isUrgent': 0,
            'isSnack': 0,
          });
          // Triggering a crisis for tomorrow or day after
          if (daysUntilCrisis == 0) daysUntilCrisis = (i % 2) + 1;
        }
      } else {
        // Normal Dinner
        final dinner = dinnerMealsList[(i + 3) % dinnerMealsList.length];
        final dinnerFoods = dinner['foods'] as List<Map<String, dynamic>>;
        final dinnerTags = (dinner['tags'] as List<dynamic>).join(',');
        final dinnerTitle = dinnerFoods.map((f) => f['name']).join(' + ');

        batch.insert('events', {
          'type': 'meal',
          'dateTime': DateTime(
            date.year,
            date.month,
            date.day,
            19,
            30,
          ).toIso8601String(),
          'title': dinnerTitle,
          'subtitle': 'Maison',
          'severity': 0,
          'tags': dinnerTags,
          'meta_data': jsonEncode({'foods': dinnerFoods}),
          'isUrgent': 0,
          'isSnack': 0,
        });
      }

      // -- BODY RESPONSE --

      // Gestion état de crise
      if (daysUntilCrisis == 1) {
        inCrisis = true;
        daysUntilCrisis = 0;
      } else if (daysUntilCrisis > 1) {
        daysUntilCrisis--;
      } else if (inCrisis) {
        // End crisis randomly after 1-2 days
        if (i % 3 == 0) inCrisis = false;
      }

      if (inCrisis) {
        // BAD DAY
        // Pain
        batch.insert('events', {
          'type': 'symptom',
          'dateTime': DateTime(
            date.year,
            date.month,
            date.day,
            9,
            0,
          ).toIso8601String(),
          'title': painLocations[i % painLocations.length], // Rotate locations
          'subtitle': 'Douleur vive',
          'severity': 7 + (i % 3), // 7, 8, 9
          'tags': 'Inflammation',
          'isUrgent': 0, 'isSnack': 0,
        });

        // Stools (Multiple)
        int stoolCount = 3 + (i % 3); // 3 to 5 times
        for (int s = 0; s < stoolCount; s++) {
          batch.insert('events', {
            'type': 'stool',
            'dateTime': DateTime(
              date.year,
              date.month,
              date.day,
              8 + (s * 3),
              15,
            ).toIso8601String(), // Spread out
            'title': 'Type ${6 + (s % 2)}', // 6 or 7
            'subtitle': 'Diarrhée',
            'severity': 0,
            'tags': 'Urgent,Liquide',
            'isUrgent': 1, 'isSnack': 0,
          });
        }
      } else {
        // GOOD DAY / NORMAL
        // Occasional mild discomfort
        if (i % 5 == 0) {
          batch.insert('events', {
            'type': 'symptom',
            'dateTime': DateTime(
              date.year,
              date.month,
              date.day,
              18,
              0,
            ).toIso8601String(),
            'title': 'Ballonnement',
            'subtitle': 'Gène',
            'severity': 2 + (i % 2),
            'tags': 'Gaz',
            'isUrgent': 0,
            'isSnack': 0,
          });
        }

        // Normal Stool (maybe skip a day occasionally)
        if (i % 7 != 0) {
          batch.insert('events', {
            'type': 'stool',
            'dateTime': DateTime(
              date.year,
              date.month,
              date.day,
              9,
              0,
            ).toIso8601String(),
            'title': 'Type ${3 + (i % 2)}', // 3 or 4
            'subtitle': 'Normal',
            'severity': 0, 'tags': '', 'isUrgent': 0, 'isSnack': 0,
          });
        }
      }
    }

    final results = await batch.commit();
    print(
      '[DB] Demo data generation complete! ${results.length} events inserted',
    );
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

  int max(int a, int b) => a > b ? a : b;
}
