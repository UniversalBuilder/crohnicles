import 'package:flutter/material.dart';

/// Brightness-aware gradients for Crohnicles event types
/// 
/// Dark theme uses lighter colors with adjusted opacity
/// for better visibility on dark backgrounds

class AppGradients {
  /// Primary gradient (General UI elements)
  static LinearGradient primary(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const LinearGradient(
        colors: [
          Color(0xFFA78BFA), // Purple 400 (lighter)
          Color(0xFFC4B5FD), // Purple 300
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return const LinearGradient(
      colors: [
        Color(0xFF6366F1), // Indigo 500
        Color(0xFF8B5CF6), // Purple 500
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
  
  /// Meal gradient (Food events)
  static LinearGradient meal(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const LinearGradient(
        colors: [
          Color(0xFFFB923C), // Orange 400
          Color(0xFFFBBF24), // Amber 400
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return const LinearGradient(
      colors: [
        Color(0xFFFB923C), // Orange 400
        Color(0xFFF472B6), // Pink 400
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
  
  /// Pain/Symptom gradient (Health issues)
  static LinearGradient pain(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const LinearGradient(
        colors: [
          Color(0xFFF87171), // Red 400
          Color(0xFFFB7185), // Rose 400
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return const LinearGradient(
      colors: [
        Color(0xFFEF4444), // Red 500
        Color(0xFFEC4899), // Pink 500
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
  
  /// Stool gradient (Bowel movements)
  static LinearGradient stool(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const LinearGradient(
        colors: [
          Color(0xFF60A5FA), // Blue 400
          Color(0xFF22D3EE), // Cyan 400
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return const LinearGradient(
      colors: [
        Color(0xFF3B82F6), // Blue 500
        Color(0xFF06B6D4), // Cyan 500
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
  
  /// Checkup gradient (Daily assessments)
  static LinearGradient checkup(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const LinearGradient(
        colors: [
          Color(0xFFA78BFA), // Purple 400
          Color(0xFFC4B5FD), // Purple 300
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return const LinearGradient(
      colors: [
        Color(0xFF8B5CF6), // Purple 500
        Color(0xFFA78BFA), // Purple 400
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
  
  /// Helper: Get gradient by event type string
  static LinearGradient forEventType(String eventType, Brightness brightness) {
    switch (eventType) {
      case 'meal':
        return meal(brightness);
      case 'symptom':
        return pain(brightness);
      case 'stool':
        return stool(brightness);
      case 'daily_checkup':
        return checkup(brightness);
      default:
        return primary(brightness);
    }
  }
}
