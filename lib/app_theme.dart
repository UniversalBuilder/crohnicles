import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Legacy color definitions (deprecated - use Theme.of(context).colorScheme)
/// These will be removed in v2.0.0 after full migration verification.
/// DO NOT USE in new code.
class AppColors {
  // Cyber Gradient Colors (2026 Sci-Fi Theme)
  static const Color primaryStart = Color(0xFF6366F1); // Indigo
  static const Color primaryEnd = Color(0xFF8B5CF6); // Purple
  
  static const Color mealStart = Color(0xFFFB923C); // Orange
  static const Color mealEnd = Color(0xFFF472B6); // Pink
  
  static const Color painStart = Color(0xFFEF4444); // Red
  static const Color painEnd = Color(0xFFEC4899); // Rose
  
  static const Color stoolStart = Color(0xFF3B82F6); // Blue
  static const Color stoolEnd = Color(0xFF06B6D4); // Cyan
  
  static const Color checkupStart = Color(0xFF8B5CF6); // Purple
  static const Color checkupEnd = Color(0xFFA78BFA); // Light Purple
  
  // Solid colors for icons/text
  static const Color primary = Color(0xFF7C3AED); // Purple 600
  static const Color meal = Color(0xFFF97316); // Orange 500
  static const Color pain = Color(0xFFEF4444); // Red 500
  static const Color stool = Color(0xFF3B82F6); // Blue 500
  static const Color checkup = Color(0xFF8B5CF6); // Purple 500
  
  // Background & Surface
  static const Color background = Color(0xFFF2F4F7); // Soft Blue-Gray
  static const Color surface = Colors.white;
  static const Color surfaceGlass = Color(0xFFFAFBFF); // Subtle blue tint
  
  // Text colors (DEPRECATED - Use Theme.of(context).colorScheme instead)
  @Deprecated('Use Theme.of(context).colorScheme.onSurface instead. Will be removed after typography refactor.')
  static const Color textPrimary = Color(0xFF1F2937);
  
  @Deprecated('Use Theme.of(context).colorScheme.onSurfaceVariant instead. Will be removed after typography refactor.')
  static const Color textSecondary = Color(0xFF6B7280);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryStart, primaryEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient mealGradient = LinearGradient(
    colors: [mealStart, mealEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient painGradient = LinearGradient(
    colors: [painStart, painEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient stoolGradient = LinearGradient(
    colors: [stoolStart, stoolEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient checkupGradient = LinearGradient(
    colors: [checkupStart, checkupEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      
      // Palette
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.meal,
        onSecondary: Colors.white,
        error: AppColors.pain,
        onError: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
      ),

      // Typography - Inter for body, Poppins for headings
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.black87),
        displayMedium: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.black87),
        titleLarge: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        titleMedium: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        bodyLarge: GoogleFonts.inter(fontSize: 16, color: AppColors.textPrimary),
        bodyMedium: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
        bodySmall: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
      ).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),

      // Card Style - Soft Shadow, No Border
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 16),
        shadowColor: Colors.black.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),

      // AppBar Style - Transparent, Bold Title
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
      
      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
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
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      
      // FloatingActionButton
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
