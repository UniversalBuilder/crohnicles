import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Material Design 3 Type Scale for Crohnicles
/// 
/// Design System:
/// - **Poppins**: Titles, headings, navigation (personality, impact)
/// - **Inter**: Body text, data, content (readability)
/// 
/// GoogleFonts automatically handles fallbacks and offline caching

class AppTextThemes {
  /// Base TextTheme without colors (colors inherited from ColorScheme)
  /// 
  /// This allows the same TextTheme to work with both light and dark themes.
  /// Colors are automatically resolved by Flutter from Theme.of(context).colorScheme
  static TextTheme base() {
    return GoogleFonts.interTextTheme().copyWith(
      // --- DISPLAYS (Hero sections, large page titles) ---
      displayLarge: GoogleFonts.poppins(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        height: 1.2,
      ),
      displayMedium: GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
        height: 1.3,
      ), // AppBar titles
      displaySmall: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ), // Dialog titles
      
      // --- HEADLINES (Major sections, card headers) ---
      headlineLarge: GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ), // Event titles
      headlineMedium: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ), // Section headers
      headlineSmall: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ), // Subsection titles
      
      // --- TITLES (Structured elements, lists) ---
      titleLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.5,
        letterSpacing: 0.15,
      ), // List items, emphasized text
      titleMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0.1,
      ), // Dense headers, form labels
      titleSmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0.1,
      ), // Compact labels, chips, badges
      
      // --- BODY (Main content, paragraphs) ---
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: 0.5,
      ), // Main content, descriptions
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.4,
        letterSpacing: 0.25,
      ), // Standard body text
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.3,
        letterSpacing: 0.4,
      ), // Metadata, timestamps, captions
      
      // --- LABELS (UI controls, buttons, inputs) ---
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.4,
        letterSpacing: 0.1,
      ), // Buttons, prominent actions
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.3,
        letterSpacing: 0.5,
      ), // Form labels, input placeholders
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.3,
        letterSpacing: 0.5,
      ), // Chart labels, helper text (WCAG AA minimum for large UI)
    );
  }
}

/// Special text styles for edge cases (emojis, monospace logs)
class AppTextStyles {
  /// Chart labels - optimized for small data visualizations
  /// Minimum 11px for WCAG AA compliance on large text
  static TextStyle chartLabel(BuildContext context) {
    return GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      height: 1.2,
    );
  }
  
  /// Chart values - slightly larger, medium weight
  static TextStyle chartValue(BuildContext context) {
    return GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.onSurface,
      height: 1.2,
    );
  }
  
  /// Emoji display - no font family (system emoji rendering)
  /// Used for food icons, symptom indicators, etc.
  static const TextStyle emoji = TextStyle(
    fontSize: 20,
    height: 1.0,
  );
  
  /// Monospace style for logs (uses Fira Code)
  /// Special case: justified for technical logs display
  static TextStyle monospace(BuildContext context) {
    return GoogleFonts.firaCode(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: Theme.of(context).colorScheme.onSurface,
      height: 1.5,
    );
  }
}
