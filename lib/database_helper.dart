import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'food_model.dart';

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
      version: 4,
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
        meta_data TEXT
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
    
    print('[DB] Seeding basic foods...');
    await _seedBasicFoods(db);
    print('[DB] Cleaning old cache...');
    await cleanOldCache(db);
    print('[DB] Database created successfully');
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
      await db.execute('ALTER TABLE foods ADD COLUMN servingSize REAL DEFAULT 100.0');
      await db.execute('ALTER TABLE foods ADD COLUMN isBasicFood INTEGER DEFAULT 0');
      
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
  }

  Future<void> _seedBasicFoods(Database db) async {
    print('[DB] Seeding 25 basic foods into DB...');
    final List<FoodModel> basicFoods = [
      // Fruits
      FoodModel(name: 'Pomme', category: 'Snack', tags: ['Fruit'], isBasicFood: true),
      FoodModel(name: 'Banane', category: 'Snack', tags: ['Fruit'], isBasicFood: true),
      FoodModel(name: 'Orange', category: 'Snack', tags: ['Fruit'], isBasicFood: true),
      FoodModel(name: 'Fraise', category: 'Snack', tags: ['Fruit'], isBasicFood: true),
      
      // Légumes
      FoodModel(name: 'Carotte', category: 'Snack', tags: ['Légume'], isBasicFood: true),
      FoodModel(name: 'Tomate', category: 'Snack', tags: ['Légume'], isBasicFood: true),
      FoodModel(name: 'Salade verte', category: 'Snack', tags: ['Légume'], isBasicFood: true),
      FoodModel(name: 'Concombre', category: 'Snack', tags: ['Légume'], isBasicFood: true),
      FoodModel(name: 'Courgette', category: 'Snack', tags: ['Légume'], isBasicFood: true),
      
      // Féculents
      FoodModel(name: 'Riz blanc', category: 'Féculent', tags: ['Féculent'], isBasicFood: true),
      FoodModel(name: 'Pâtes nature', category: 'Féculent', tags: ['Féculent', 'Gluten'], isBasicFood: true),
      FoodModel(name: 'Pain', category: 'Féculent', tags: ['Féculent', 'Gluten'], isBasicFood: true),
      FoodModel(name: 'Pomme de terre', category: 'Féculent', tags: ['Féculent'], isBasicFood: true),
      
      // Protéines
      FoodModel(name: 'Poulet', category: 'Protéine', tags: ['Protéine'], isBasicFood: true),
      FoodModel(name: 'Bœuf', category: 'Protéine', tags: ['Protéine'], isBasicFood: true),
      FoodModel(name: 'Poisson', category: 'Protéine', tags: ['Protéine'], isBasicFood: true),
      FoodModel(name: 'Œuf', category: 'Protéine', tags: ['Protéine'], isBasicFood: true),
      
      // Laitages
      FoodModel(name: 'Yaourt', category: 'Snack', tags: ['Laitier', 'Lactose'], isBasicFood: true),
      FoodModel(name: 'Fromage', category: 'Snack', tags: ['Laitier', 'Lactose'], isBasicFood: true),
      FoodModel(name: 'Lait', category: 'Boisson', tags: ['Laitier', 'Lactose'], isBasicFood: true),
      
      // Boissons
      FoodModel(name: 'Eau', category: 'Boisson', tags: [], isBasicFood: true),
      FoodModel(name: 'Café', category: 'Boisson', tags: ['Caféine'], isBasicFood: true),
      FoodModel(name: 'Thé', category: 'Boisson', tags: ['Caféine'], isBasicFood: true),
      
      // Autres
      FoodModel(name: 'Huile d\'olive', category: 'Snack', tags: ['Gras'], isBasicFood: true),
      FoodModel(name: 'Beurre', category: 'Snack', tags: ['Gras', 'Lactose'], isBasicFood: true),
    ];

    Batch batch = db.batch();
    for (var food in basicFoods) {
      batch.insert('foods', food.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    final results = await batch.commit();
    print('[DB] ${basicFoods.length} basic foods inserted successfully (${results.length} operations)');
  }
  
  // Clean cache older than 90 days
  Future<void> cleanOldCache([Database? db]) async {
    db ??= await database;
    int cutoff = DateTime.now().subtract(const Duration(days: 90)).millisecondsSinceEpoch;
    await db.delete('products_cache', where: 'timestamp < ?', whereArgs: [cutoff]);
  }

  Future<int> insertFood(FoodModel food) async {
    Database db = await database;
    return await db.insert('foods', food.toMap());
  }

  Future<List<FoodModel>> searchFoods(String query) async {
    print('[DB] Searching foods with query: \"$query\"');
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'foods',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      limit: 20
    );
    print('[DB] Found ${maps.length} results for \"$query\"');
    return List.generate(maps.length, (i) {
      return FoodModel.fromMap(maps[i]);
    });
  }
  
  Future<List<FoodModel>> getAllFoods() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('foods', orderBy: 'name ASC');
     return List.generate(maps.length, (i) {
      return FoodModel.fromMap(maps[i]);
    });
  }

  Future<void> generateDemoData() async {
    print('[DB] Starting demo data generation...');
    Database db = await database;
    await db.delete('events');
    print('[DB] Deleted all existing events');

    final now = DateTime.now();
    Batch batch = db.batch();
    
    // Listes pour l'aléatoire
    final List<String> painLocations = [
      "Fosse Iliaque D.", "Hypogastre", "Ombilic", "Flanc Gauche", "Épigastre"
    ];
    
    final List<String> triggers = ["Bière", "Curry Indien", "Raclette", "Burger Frites", "Pizza Margherita"];
    final Map<String, String> triggerTags = {
        "Bière": "Alcool,Gaz,Gluten",
        "Curry Indien": "Épicé,Lactose,Riz",
        "Raclette": "Gras,Lactose,Copieux,Charcuterie",
        "Burger Frites": "Gras,Gluten,Friture",
        "Pizza Margherita": "Gluten,Lactose,Gras"
    };
    
    final List<Map<String, String>> healthyMeals = [
       {'title': 'Poulet Riz', 'tags': 'Protéine,Sans Résidu'},
       {'title': 'Saumon Vapeur', 'tags': 'Protéine,Omega-3'},
       {'title': 'Pâtes Huile Olive', 'tags': 'Féculent,Gluten'},
       {'title': 'Omelette', 'tags': 'Protéine,Végétarien'},
       {'title': 'Purée Carotte', 'tags': 'Fibres,Vitamines,Douceur'},
       {'title': 'Riz Dinde', 'tags': 'Protéine,Féculent,Maigre'}
    ];
    
    // Simulation state
    int daysUntilCrisis = 0; // Countdown
    bool inCrisis = false;

    for (int i = 30; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final weekDay = date.weekday; 
      
      // Determine if today is a "Risk" day (Friday/Saturday)
      bool riskDay = (weekDay == 5 || weekDay == 6);
      
      // -- MEALS --
      // Lunch is usually okay
      final lunch = healthyMeals[i % healthyMeals.length];
      batch.insert('events', {
           'type': 'meal',
           'dateTime': DateTime(date.year, date.month, date.day, 12, 30).toIso8601String(),
           'title': lunch['title'],
           'subtitle': 'Maison',
           'severity': 0,
           'tags': lunch['tags'],
           'isUrgent': 0, 'isSnack': 0,
       });

      // Dinner
      if (riskDay) {
          // Trigger Food!
          // Sauf si on est déjà en crise, auquel cas on mange léger
          if (inCrisis) {
             batch.insert('events', {
               'type': 'meal',
               'dateTime': DateTime(date.year, date.month, date.day, 20, 0).toIso8601String(),
               'title': 'Bouillon',
               'subtitle': 'Diète',
               'severity': 0, 'tags': 'Liquide,Sel', 'isUrgent': 0, 'isSnack': 0,
             });
          } else {
             final trigger = triggers[i % 5]; // Randomish
             batch.insert('events', {
               'type': 'meal',
               'dateTime': DateTime(date.year, date.month, date.day, 20, 0).toIso8601String(),
               'title': trigger,
               'subtitle': 'Sortie',
               'severity': 0, 
               'tags': triggerTags[trigger],
               'isUrgent': 0, 'isSnack': 0,
             });
             // Triggering a crisis for tomorrow or day after
             if (daysUntilCrisis == 0) daysUntilCrisis = (i % 2) + 1; 
          }
      } else {
          // Normal Dinner
          final dinner = healthyMeals[(i+3) % healthyMeals.length];
          batch.insert('events', {
             'type': 'meal',
             'dateTime': DateTime(date.year, date.month, date.day, 19, 30).toIso8601String(),
             'title': dinner['title'],
             'subtitle': 'Maison',
             'severity': 0, 'tags': dinner['tags'], 'isUrgent': 0, 'isSnack': 0,
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
             'dateTime': DateTime(date.year, date.month, date.day, 9, 0).toIso8601String(),
             'title': painLocations[i % painLocations.length], // Rotate locations
             'subtitle': 'Douleur vive',
             'severity': 7 + (i % 3), // 7, 8, 9
             'tags': 'Inflammation',
             'isUrgent': 0, 'isSnack': 0,
          });
          
          // Stools (Multiple)
          int stoolCount = 3 + (i % 3); // 3 to 5 times
          for(int s=0; s<stoolCount; s++) {
             batch.insert('events', {
               'type': 'stool',
               'dateTime': DateTime(date.year, date.month, date.day, 8 + (s*3), 15).toIso8601String(), // Spread out
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
               'dateTime': DateTime(date.year, date.month, date.day, 18, 0).toIso8601String(),
               'title': 'Ballonnement',
               'subtitle': 'Gène',
               'severity': 2 + (i % 2),
               'tags': 'Gaz', 'isUrgent': 0, 'isSnack': 0,
             });
          }
          
          // Normal Stool (maybe skip a day occasionally)
          if (i % 7 != 0) {
             batch.insert('events', {
               'type': 'stool',
               'dateTime': DateTime(date.year, date.month, date.day, 9, 0).toIso8601String(),
               'title': 'Type ${3 + (i%2)}', // 3 or 4
               'subtitle': 'Normal',
               'severity': 0, 'tags': '', 'isUrgent': 0, 'isSnack': 0,
             });
          }
      }
    }
    
    final results = await batch.commit();
    print('[DB] Demo data generation complete! ${results.length} events inserted');
  }
  
  // --- Analysis Helpers ---
  Future<Map<String, int>> getSymptomZones(int days) async {
      Database db = await database;
      // Get all symptom events
      final now = DateTime.now();
      final start = now.subtract(Duration(days: days)).toIso8601String();
      
      final res = await db.query('events', 
        columns: ['title'],
        where: "type = ? AND dateTime >= ?", 
        whereArgs: ['symptom', start]
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
    return await db.rawQuery('''
      SELECT substr(dateTime, 1, 10) as date, MAX(severity) as max_severity
      FROM events
      WHERE type = 'symptom' AND dateTime >= ?
      GROUP BY substr(dateTime, 1, 10)
      ORDER BY date ASC
    ''', [startDate]);
  }

  // Get stool count per day for the last X days
  Future<List<Map<String, dynamic>>> getStoolFrequency(int days) async {
    Database db = await database;
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days)).toIso8601String();

    // Group by date, count entries, and average Bristol type (if stored clearly, but here we count)
    // We can try to extract Bristol type from title "Type X" if needed, but for now just count.
    return await db.rawQuery('''
      SELECT substr(dateTime, 1, 10) as date, COUNT(*) as count
      FROM events
      WHERE type = 'stool' AND dateTime >= ?
      GROUP BY substr(dateTime, 1, 10)
      ORDER BY date ASC
    ''', [startDate]);
  }

  // Get last 3 meals before a specific date (or just last meals overall if date not provided)
  Future<List<Map<String, dynamic>>> getLastMeals(int limit, {String? beforeDate}) async {
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
}
