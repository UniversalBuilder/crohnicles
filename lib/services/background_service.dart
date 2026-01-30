import 'dart:io';
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
        // Note: SharedPreferences on Android might need force reload in bg
        // if (Platform.isAndroid) SharedPreferencesAndroid.registerWith();
        
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
            
            // 3. Save to DB
            final dbPath = await getDatabasesPath();
            final path = join(dbPath, 'crohnicles.db');
            
            // Ensure we don't lock the DB for too long
            final db = await openDatabase(path);
            
            // We store this as a 'context_log' event or similar
            // Assuming we have an 'events' table, we can create a system event
            await db.insert('events', {
              'type': 'context_log',
              'dateTime': DateTime.now().toIso8601String(),
              'title': 'Relevé Météo Auto',
              'notes': 'Relevé automatique',
              'severity': 0,
              'meta_data': '{"temperature": ${data['temperature_2m']}, "pressure": ${data['surface_pressure']}, "humidity": ${data['relative_humidity_2m']}, "weather_code": ${data['weather_code']}, "source": "background"}',
              'imagePath': null,
              'isSnack': 0,
              'tags': '',
            });
            
            await db.close();
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
