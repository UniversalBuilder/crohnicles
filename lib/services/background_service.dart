import 'package:workmanager/workmanager.dart';
import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

const fetchWeatherTask = "fetchWeatherTask";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == fetchWeatherTask) {
      try {
        print('[BackgroundService] 🌦️ Starting weather fetch task...');
        
        // 1. Get stored preferences (Last known location)
        final prefs = await SharedPreferences.getInstance();
        final lat = prefs.getDouble('last_lat') ?? 48.85; // Default Paris
        final lng = prefs.getDouble('last_lng') ?? 2.35;
        
        print('[BackgroundService] Location: $lat, $lng');

        // 2. Call OpenMeteo API
        final dio = Dio();
        final response = await dio.get(
          'https://api.open-meteo.com/v1/forecast',
          queryParameters: {
            'latitude': lat,
            'longitude': lng,
            'current': 'temperature_2m,surface_pressure,relative_humidity_2m,weather_code',
          },
        );

        if (response.statusCode == 200) {
            final data = response.data['current'];
            print('[BackgroundService] API Success: $data');
            
            // 3. Save to DB - Explicit path handling to match DatabaseHelper
            // Using getApplicationDocumentsDirectory to match main app's DatabaseHelper logic
            // We do this explicitly to avoid Singleton/Isolate issues
            final documentsDirectory = await getApplicationDocumentsDirectory();
            final dbPath = join(documentsDirectory.path, 'crohnicles.db');
            print('[BackgroundService] DB Path: $dbPath');

            final db = await openDatabase(dbPath, version: 10, 
              onCreate: (db, version) async {
                 // Fallback: If DB doesn't exist in this isolate for some reason
                 await db.execute('''
                  CREATE TABLE IF NOT EXISTS events(
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
              },
              onOpen: (db) async {
                 // Ensure table exists even if DB exists (e.g. corruption or empty file)
                 await db.execute('''
                  CREATE TABLE IF NOT EXISTS events(
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
              }
            );
            
            // We store this as a 'context_log' event or similar
            // Assuming we have an 'events' table, we can create a system event
            await db.insert('events', {
              'type': 'context_log',
              'dateTime': DateTime.now().toIso8601String(),
              'title': 'Relevé Météo Auto',
              'subtitle': 'Relevé automatique',
              'severity': 0,
              'meta_data': '{"temperature": ${data['temperature_2m']}, "pressure": ${data['surface_pressure']}, "humidity": ${data['relative_humidity_2m']}, "weather_code": ${data['weather_code']}, "source": "background"}',
              'imagePath': null,
              'isSnack': 0,
              'tags': '',
            });
            
            // DatabaseHelper handles closing/lifecycle usually, but if we accessed it via singleton 
            // and it stays open, that's fine for the background task. 
            // But we shouldn't close it if it's shared? 
            // DatabaseHelper singleton keeps it open.
            
            print('[BackgroundService] ✅ Weather saved to DB');
        } else {
             print('[BackgroundService] API Error: ${response.statusCode}');
             return Future.value(false);
        }
      } catch (e) {
        print("[BackgroundService] ❌ Error: $e");
        return Future.value(false); // Retry later
      }
    }
    return Future.value(true);
  });
}

class BackgroundService {
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true, // TODO: Set false for release
    );
    print('[BackgroundService] Initialized');
  }

  static Future<void> registerPeriodicTask() async {
     // Save default location if needed (Paris)
     final prefs = await SharedPreferences.getInstance();
     if (!prefs.containsKey('last_lat')) {
        await prefs.setDouble('last_lat', 48.85);
        await prefs.setDouble('last_lng', 2.35);
     }

    await Workmanager().registerPeriodicTask(
      "weather_auto_fetch", // Unique name
      fetchWeatherTask, 
      frequency: const Duration(hours: 1), 
      constraints: Constraints(
        networkType: NetworkType.connected, 
      ),
      initialDelay: const Duration(minutes: 15),
    );
    print('[BackgroundService] Periodic task registered');
  }
}
