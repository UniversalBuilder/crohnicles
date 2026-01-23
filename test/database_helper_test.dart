import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:crohnicles/database_helper.dart';
import 'package:crohnicles/food_model.dart';
import 'package:crohnicles/event_model.dart';

void main() {
  // Initialize FFI for desktop testing
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseHelper Concurrent Access', () {
    test('Multiple simultaneous database getters use same Completer', () async {
      final helper = DatabaseHelper();
      
      // Simulate multiple concurrent calls
      final futures = List.generate(10, (_) => helper.database);
      final databases = await Future.wait(futures);
      
      // All should return the same database instance
      expect(databases.toSet().length, 1);
    });

    test('Database initializes with correct tables', () async {
      final helper = DatabaseHelper();
      final db = await helper.database;
      
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'"
      );
      final tableNames = tables.map((t) => t['name']).toList();
      
      expect(tableNames, contains('events'));
      expect(tableNames, contains('foods'));
      expect(tableNames, contains('products_cache'));
    });
  });

  group('Food Database Operations', () {
    late DatabaseHelper helper;

    setUp(() async {
      helper = DatabaseHelper();
      await helper.database; // Ensure initialization
    });

    test('Seeds database with 25+ basic foods', () async {
      final foods = await helper.searchFoods('');
      expect(foods.length, greaterThanOrEqualTo(25));
    });

    test('Search foods returns matching results', () async {
      final results = await helper.searchFoods('Poulet');
      expect(results.any((f) => f.name.contains('Poulet')), true);
    });

    test('Insert and retrieve food with nutrition data', () async {
      final food = FoodModel(
        id: 0,
        name: 'Test Food',
        category: 'Protéine',
        tags: ['Test', 'Protein'],
        proteins: 25.0,
        fats: 10.0,
        carbs: 5.0,
        fiber: 2.0,
        sugars: 1.0,
      );

      await helper.insertFood(food);
      final results = await helper.searchFoods('Test Food');
      
      expect(results.length, 1);
      expect(results.first.proteins, 25.0);
      expect(results.first.tags, contains('Test'));
    });
  });

  group('Event Operations', () {
    late DatabaseHelper helper;

    setUp(() async {
      helper = DatabaseHelper();
      await helper.database;
    });

    test('Insert meal event with foods metadata', () async {
      final event = EventModel(
        id: 0,
        type: EventType.meal,
        dateTime: DateTime.now().toIso8601String(),
        title: 'Test Meal',
        subtitle: 'Pâtes',
        tags: ['Féculent', 'Protéine'],
        metaData: '[{"name":"Pâtes","category":"Féculent"}]',
      );

      final id = await helper.insertEvent(event.toMap());
      expect(id, greaterThan(0));

      final events = await helper.getEvents();
      expect(events.any((e) => e['title'] == 'Test Meal'), true);
    });

    test('Insert symptom event with severity', () async {
      final event = EventModel(
        id: 0,
        type: EventType.symptom,
        dateTime: DateTime.now().toIso8601String(),
        title: 'Douleur Abdominale',
        subtitle: 'Zone épigastrique',
        severity: 7,
        tags: ['Abdomen'],
        metaData: '{"zones":["Épigastre","Ombilic"]}',
      );

      await helper.insertEvent(event.toMap());
      final events = await helper.getEvents();
      final symptom = events.firstWhere((e) => e['type'] == 'symptom');
      
      expect(symptom['severity'], 7);
      expect(symptom['meta_data'], contains('Épigastre'));
    });
  });

  group('Analytics Queries', () {
    late DatabaseHelper helper;

    setUp(() async {
      helper = DatabaseHelper();
      await helper.database;
      
      // Insert realistic test data
      final now = DateTime.now();
      await helper.insertEvent(EventModel(
        id: 0,
        type: EventType.symptom,
        dateTime: now.subtract(const Duration(days: 1)).toIso8601String(),
        title: 'Douleur',
        subtitle: 'Abdominale',
        severity: 8,
        tags: ['Abdomen'],
      ).toMap());
      await helper.insertEvent(EventModel(
        id: 0,
        type: EventType.stool,
        dateTime: now.subtract(const Duration(days: 1)).toIso8601String(),
        title: 'Type 6',
        subtitle: 'Diarrhée',
        tags: ['Diarrhée'],
      ).toMap());
    });

    test('getPainEvolution returns data points', () async {
      final evolution = await helper.getPainEvolution(7);
      expect(evolution, isNotEmpty);
      expect(evolution.first.containsKey('date'), true);
      expect(evolution.first.containsKey('avg_severity'), true);
    });

    test('getStoolFrequency calculates daily counts', () async {
      final frequency = await helper.getStoolFrequency(7);
      expect(frequency, isNotEmpty);
    });
  });

  group('Cache Management', () {
    late DatabaseHelper helper;

    setUp(() async {
      helper = DatabaseHelper();
      await helper.database;
    });

    test('cleanOldCache removes 90+ day old entries', () async {
      final db = await helper.database;
      final oldDate = DateTime.now().subtract(const Duration(days: 100));
      
      await db.insert('products_cache', {
        'barcode': '123456',
        'data': '{"name":"Old Product"}',
        'cached_at': oldDate.toIso8601String(),
      });

      await helper.cleanOldCache(db);
      
      final remaining = await db.query(
        'products_cache',
        where: 'barcode = ?',
        whereArgs: ['123456'],
      );
      expect(remaining.isEmpty, true);
    });
  });
}
