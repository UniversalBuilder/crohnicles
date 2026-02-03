// import 'package:geolocator/geolocator.dart';  // Temporarily disabled for Windows build
import 'package:weather/weather.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/context_model.dart';
import '../database_helper.dart';

/// Service for capturing environmental context (weather, location) at event time
/// Note: Location features temporarily disabled on Windows due to NuGet dependency
class ContextService {
  WeatherFactory? _weatherFactory;
  // bool _permissionGranted = false;  // Disabled for Windows

  ContextService() {
    // Initialize weather factory if API key is configured in .env
    final apiKey = dotenv.env['OPENWEATHER_API_KEY'];
    if (apiKey != null && apiKey.isNotEmpty) {
      _weatherFactory = WeatherFactory(apiKey);
    }
  }

  /// Request location and weather permissions from user
  /// Note: Currently disabled on Windows due to geolocator dependency
  Future<bool> requestPermissions() async {
    print('[Context] Location features disabled on Windows - using datetime only');
    return false;
    
    // TODO: Re-enable when geolocator works on Windows
    // Check location permission
    // LocationPermission permission = await Geolocator.checkPermission();
    // 
    // if (permission == LocationPermission.denied) {
    //   permission = await Geolocator.requestPermission();
    //   if (permission == LocationPermission.denied) {
    //     print('[Context] Location permission denied');
    //     return false;
    //   }
    // }
    //
    // if (permission == LocationPermission.deniedForever) {
    //   print('[Context] Location permission denied forever');
    //   return false;
    // }
    //
    // _permissionGranted = true;
    // print('[Context] Permissions granted');
    // return true;
  }

  /// Capture current environmental context
  Future<ContextModel> captureCurrentContext() async {
    final now = DateTime.now();
    
    // Create basic context from datetime
    ContextModel context = ContextModel.fromDateTime(now);

    // TODO: Re-enable weather when geolocator works on Windows
    // Try to enhance with location and weather if permissions granted
    // if (_permissionGranted && _weatherFactory != null) {
    //   try {
    //     // Get current position
    //     final position = await Geolocator.getCurrentPosition(
    //       desiredAccuracy: LocationAccuracy.low,
    //       timeLimit: const Duration(seconds: 5),
    //     );
    //
    //     // Get weather data
    //     final weather = await _weatherFactory!.currentWeatherByLocation(
    //       position.latitude,
    //       position.longitude,
    //     );
    //
    //     // Get pressure change from 6h ago (cached)
    //     final pressureChange = await _getPressureChange6h(position.latitude, position.longitude);
    //
    //     // Create enhanced context
    //     context = ContextModel.fromDateTime(
    //       now,
    //       temperature: weather.temperature?.celsius,
    //       weatherCondition: _normalizeWeatherCondition(weather.weatherConditionCode),
    //       barometricPressure: weather.pressure?.toDouble(),
    //       pressureChange6h: pressureChange,
    //       humidity: weather.humidity?.toDouble(),
    //       latitude: position.latitude,
    //       longitude: position.longitude,
    //     );
    //
    //     print('[Context] Captured weather: ${weather.temperature?.celsius}°C, ${weather.weatherMain}');
    //   } catch (e) {
    //     print('[Context] Error capturing weather data: $e');
    //     // Return basic context if weather capture fails
    //   }
    // }

    print('[Context] Using basic datetime context (weather disabled on Windows)');
    return context;
  }

  // TODO: Re-enable when geolocator works on Windows
  /// Get pressure change from 6 hours ago by checking cache
  // Future<double?> _getPressureChange6h(double lat, double lng) async {
  //   try {
  //     final db = DatabaseHelper();
  //     final dbInstance = await db.database;
  //     
  //     final sixHoursAgo = DateTime.now().subtract(const Duration(hours: 6));
  //     final result = await dbInstance.query(
  //       'weather_cache',
  //       where: 'date = ?',
  //       whereArgs: [sixHoursAgo.toIso8601String().substring(0, 10)],
  //       limit: 1,
  //     );
  //
  //     if (result.isNotEmpty && result.first['pressure'] != null) {
  //       final oldPressure = result.first['pressure'] as double;
  //       final currentWeather = await _weatherFactory!.currentWeatherByLocation(lat, lng);
  //       final currentPressure = currentWeather.pressure?.toDouble();
  //       
  //       if (currentPressure != null) {
  //         return currentPressure - oldPressure;
  //       }
  //     }
  //   } catch (e) {
  //     print('[Context] Error calculating pressure change: $e');
  //   }
  //   return null;
  // }

  /// Normalize weather condition codes to simple categories
  String _normalizeWeatherCondition(int? code) {
    if (code == null) return 'unknown';
    
    // OpenWeatherMap condition codes
    if (code >= 200 && code < 300) return 'stormy'; // Thunderstorm
    if (code >= 300 && code < 400) return 'rainy'; // Drizzle
    if (code >= 500 && code < 600) return 'rainy'; // Rain
    if (code >= 600 && code < 700) return 'snowy'; // Snow
    if (code >= 700 && code < 800) return 'foggy'; // Atmosphere
    if (code == 800) return 'sunny'; // Clear
    if (code > 800) return 'cloudy'; // Clouds
    
    return 'unknown';
  }

  /// Cache current weather data for future pressure change calculations
  Future<void> cacheWeatherData(double lat, double lng) async {
    if (_weatherFactory == null) return;

    try {
      final weather = await _weatherFactory!.currentWeatherByLocation(lat, lng);
      final db = DatabaseHelper();
      final dbInstance = await db.database;

      await dbInstance.insert(
        'weather_cache',
        {
          'date': DateTime.now().toIso8601String().substring(0, 10),
          'temperature': weather.temperature?.celsius,
          'pressure': weather.pressure?.toDouble(),
          'condition': _normalizeWeatherCondition(weather.weatherConditionCode),
          'humidity': weather.humidity?.toDouble(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      print('[Context] Weather data cached');
    } catch (e) {
      print('[Context] Error caching weather: $e');
    }
  }

  /// Clean old weather cache (keep last 90 days)
  Future<void> cleanOldWeatherCache() async {
    try {
      final db = DatabaseHelper();
      final dbInstance = await db.database;
      
      final ninetyDaysAgo = DateTime.now().subtract(const Duration(days: 90));
      await dbInstance.delete(
        'weather_cache',
        where: 'date < ?',
        whereArgs: [ninetyDaysAgo.toIso8601String().substring(0, 10)],
      );

      print('[Context] Old weather cache cleaned');
    } catch (e) {
      print('[Context] Error cleaning weather cache: $e');
    }
  }
}
