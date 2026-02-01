import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme management provider for Crohnicles app
/// 
/// Manages theme mode (light/dark/system) with persistence via SharedPreferences.
/// Notifies listeners when theme changes to trigger rebuilds.
/// 
/// Usage:
/// ```dart
/// // In main.dart
/// ChangeNotifierProvider<ThemeProvider>(
///   create: (_) => ThemeProvider()..loadThemeMode(),
///   child: MyApp(),
/// )
/// 
/// // In MaterialApp
/// Consumer<ThemeProvider>(
///   builder: (context, themeProvider, _) => MaterialApp(
///     themeMode: themeProvider.themeMode,
///     ...
///   ),
/// )
/// 
/// // In settings
/// context.read<ThemeProvider>().setThemeMode(ThemeMode.dark)
/// ```

class ThemeProvider extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  
  ThemeMode _themeMode = ThemeMode.system;
  
  /// Current theme mode
  ThemeMode get themeMode => _themeMode;
  
  /// Load theme mode from SharedPreferences
  /// Call this once during app initialization
  Future<void> loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeModeString = prefs.getString(_themeModeKey);
      
      if (themeModeString != null) {
        _themeMode = _parseThemeMode(themeModeString);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading theme mode: $e');
      // Fallback to system default
      _themeMode = ThemeMode.system;
    }
  }
  
  /// Set theme mode and persist to SharedPreferences
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    
    _themeMode = mode;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, mode.toString());
    } catch (e) {
      debugPrint('Error saving theme mode: $e');
    }
  }
  
  /// Parse ThemeMode from string
  ThemeMode _parseThemeMode(String themeModeString) {
    switch (themeModeString) {
      case 'ThemeMode.light':
        return ThemeMode.light;
      case 'ThemeMode.dark':
        return ThemeMode.dark;
      case 'ThemeMode.system':
      default:
        return ThemeMode.system;
    }
  }
  
  /// Toggle between light and dark (ignores system)
  Future<void> toggleTheme() async {
    final newMode = _themeMode == ThemeMode.light 
        ? ThemeMode.dark 
        : ThemeMode.light;
    await setThemeMode(newMode);
  }
  
  /// Check if current effective theme is dark
  /// Requires BuildContext to check system brightness when mode is system
  bool isDarkMode(BuildContext context) {
    if (_themeMode == ThemeMode.system) {
      return MediaQuery.of(context).platformBrightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }
}
