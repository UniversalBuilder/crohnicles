import 'dart:convert';

/// Environmental context data captured at event time
class ContextModel {
  final double? temperature; // Celsius
  final String? weatherCondition; // sunny, rainy, cloudy, stormy, etc.
  final double? barometricPressure; // hPa
  final double? pressureChange6h; // Delta from 6 hours ago
  final double? humidity; // Percentage 0-100
  final double? latitude;
  final double? longitude;
  final String timeOfDay; // morning, afternoon, evening, night
  final int dayOfWeek; // 0 = Sunday, 6 = Saturday
  final bool isWeekend;
  final String season; // spring, summer, fall, winter
  final DateTime capturedAt;

  ContextModel({
    this.temperature,
    this.weatherCondition,
    this.barometricPressure,
    this.pressureChange6h,
    this.humidity,
    this.latitude,
    this.longitude,
    required this.timeOfDay,
    required this.dayOfWeek,
    required this.isWeekend,
    required this.season,
    required this.capturedAt,
  });

  /// Determine time of day from hour
  static String getTimeOfDay(int hour) {
    if (hour >= 5 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'afternoon';
    if (hour >= 17 && hour < 22) return 'evening';
    return 'night';
  }

  /// Determine season from month (Northern Hemisphere)
  static String getSeason(int month) {
    if (month >= 3 && month <= 5) return 'spring';
    if (month >= 6 && month <= 8) return 'summer';
    if (month >= 9 && month <= 11) return 'fall';
    return 'winter';
  }

  /// Create context from DateTime
  factory ContextModel.fromDateTime(DateTime dt, {
    double? temperature,
    String? weatherCondition,
    double? barometricPressure,
    double? pressureChange6h,
    double? humidity,
    double? latitude,
    double? longitude,
  }) {
    return ContextModel(
      temperature: temperature,
      weatherCondition: weatherCondition,
      barometricPressure: barometricPressure,
      pressureChange6h: pressureChange6h,
      humidity: humidity,
      latitude: latitude,
      longitude: longitude,
      timeOfDay: getTimeOfDay(dt.hour),
      dayOfWeek: dt.weekday % 7, // Convert Monday=1 to Sunday=0
      isWeekend: dt.weekday == DateTime.saturday || dt.weekday == DateTime.sunday,
      season: getSeason(dt.month),
      capturedAt: dt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'temperature': temperature,
      'weather_condition': weatherCondition,
      'barometric_pressure': barometricPressure,
      'pressure_change_6h': pressureChange6h,
      'humidity': humidity,
      'latitude': latitude,
      'longitude': longitude,
      'time_of_day': timeOfDay,
      'day_of_week': dayOfWeek,
      'is_weekend': isWeekend ? 1 : 0,
      'season': season,
      'captured_at': capturedAt.toIso8601String(),
    };
  }

  factory ContextModel.fromMap(Map<String, dynamic> map) {
    return ContextModel(
      temperature: map['temperature']?.toDouble(),
      weatherCondition: map['weather_condition'],
      barometricPressure: map['barometric_pressure']?.toDouble(),
      pressureChange6h: map['pressure_change_6h']?.toDouble(),
      humidity: map['humidity']?.toDouble(),
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      timeOfDay: map['time_of_day'] ?? 'unknown',
      dayOfWeek: map['day_of_week'] ?? 0,
      isWeekend: map['is_weekend'] == 1,
      season: map['season'] ?? 'unknown',
      capturedAt: DateTime.parse(map['captured_at']),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory ContextModel.fromJson(String source) =>
      ContextModel.fromMap(jsonDecode(source));

  /// Check if context has weather data
  bool get hasWeatherData =>
      temperature != null && weatherCondition != null && barometricPressure != null;

  /// Check if high humidity
  bool get isHighHumidity => humidity != null && humidity! > 70;

  /// Check if pressure dropping significantly
  bool get isPressureDropping =>
      pressureChange6h != null && pressureChange6h! < -5;
}
