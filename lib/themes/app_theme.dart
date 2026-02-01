import 'package:flutter/material.dart';
import 'color_schemes.dart';
import 'text_themes.dart';

/// Centralized theme factory for Crohnicles app
/// 
/// Provides both light and dark themes with:
/// - WCAG AA compliant color contrast (≥4.5:1)
/// - Material Design 3 type scale
/// - Consistent component styling
/// - Responsive text scaling (handled by ResponsiveWrapper)

class AppTheme {
  /// Light theme
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: AppColorSchemes.light,
      textTheme: AppTextThemes.base(),
      scaffoldBackgroundColor: AppColorSchemes.light.surfaceContainerHighest,
      
      // Card Style - Soft Shadow, No Border
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 16),
        shadowColor: Colors.black.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      
      // AppBar Style - Transparent, uses displayMedium from textTheme
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      
      // Input Fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppColorSchemes.light.primary,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      
      // FloatingActionButton
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      
      // Divider
      dividerTheme: DividerThemeData(
        color: AppColorSchemes.light.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      
      // Bottom Navigation Bar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColorSchemes.light.surface,
        selectedItemColor: AppColorSchemes.light.primary,
        unselectedItemColor: AppColorSchemes.light.onSurfaceVariant,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      
      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: AppColorSchemes.light.surfaceContainerHigh,
        labelStyle: AppTextThemes.base().titleSmall,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
  
  /// Dark theme
  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: AppColorSchemes.dark,
      textTheme: AppTextThemes.base(),
      scaffoldBackgroundColor: AppColorSchemes.dark.surfaceContainerHighest,
      
      // Card Style - Elevated surface in dark mode
      cardTheme: CardThemeData(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 16),
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      
      // AppBar Style - Slightly elevated surface
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 2,
      ),
      
      // Input Fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppColorSchemes.dark.primary,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      
      // FloatingActionButton
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      
      // Divider
      dividerTheme: DividerThemeData(
        color: AppColorSchemes.dark.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      
      // Bottom Navigation Bar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColorSchemes.dark.surface,
        selectedItemColor: AppColorSchemes.dark.primary,
        unselectedItemColor: AppColorSchemes.dark.onSurfaceVariant,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      
      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: AppColorSchemes.dark.surfaceContainerHigh,
        labelStyle: AppTextThemes.base().titleSmall,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
