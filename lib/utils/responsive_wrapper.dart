import 'package:flutter/material.dart';

/// Responsive text scaling wrapper for Crohnicles app
/// 
/// Applies adaptive text scaling based on screen width to ensure:
/// - Readability on small devices (320px width)
/// - Optimal sizing on standard phones (375-414px)
/// - Comfortable reading on tablets (600px+)
/// 
/// Scale factors:
/// - 320px: 0.85 (small phones like iPhone SE)
/// - 375px: 1.0 (baseline - standard iPhone)
/// - 414px: 1.1 (large phones like iPhone Pro Max)
/// - 600px+: 1.2 (tablets like iPad Mini)
/// 
/// Usage:
/// ```dart
/// MaterialApp(
///   home: ResponsiveWrapper(
///     child: Scaffold(...),
///   ),
/// )
/// ```

class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  
  const ResponsiveWrapper({
    super.key,
    required this.child,
  });
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final scale = _getScaleFactor(width);
        
        // Get base theme
        final baseTheme = Theme.of(context);
        
        // Apply scaled textTheme
        return Theme(
          data: baseTheme.copyWith(
            textTheme: _scaleTextTheme(baseTheme.textTheme, scale),
          ),
          child: child,
        );
      },
    );
  }
  
  /// Calculate scale factor based on screen width
  /// 
  /// Breakpoints:
  /// - < 360px: Scale down to 0.85 (small phones)
  /// - 360-374px: Scale to 0.92 (approaching baseline)
  /// - 375-413px: Scale 1.0 (baseline, standard phones)
  /// - 414-599px: Scale 1.05 (large phones)
  /// - ≥ 600px: Scale 1.2 (tablets)
  double _getScaleFactor(double width) {
    const minScale = 0.85;
    const maxScale = 1.2;
    
    if (width < 360) {
      return minScale;
    } else if (width < 375) {
      // Gradual scale from 0.85 to 1.0
      return minScale + ((width - 360) / (375 - 360)) * (1.0 - minScale);
    } else if (width < 414) {
      return 1.0;
    } else if (width < 600) {
      // Gradual scale from 1.0 to 1.05
      return 1.0 + ((width - 414) / (600 - 414)) * 0.05;
    } else {
      return maxScale;
    }
  }
  
  /// Scale entire TextTheme by given factor
  /// 
  /// Applies scale to fontSize while preserving other properties
  /// (fontWeight, letterSpacing, height, fontFamily, etc.)
  TextTheme _scaleTextTheme(TextTheme base, double scale) {
    return TextTheme(
      displayLarge: _scaleTextStyle(base.displayLarge, scale),
      displayMedium: _scaleTextStyle(base.displayMedium, scale),
      displaySmall: _scaleTextStyle(base.displaySmall, scale),
      headlineLarge: _scaleTextStyle(base.headlineLarge, scale),
      headlineMedium: _scaleTextStyle(base.headlineMedium, scale),
      headlineSmall: _scaleTextStyle(base.headlineSmall, scale),
      titleLarge: _scaleTextStyle(base.titleLarge, scale),
      titleMedium: _scaleTextStyle(base.titleMedium, scale),
      titleSmall: _scaleTextStyle(base.titleSmall, scale),
      bodyLarge: _scaleTextStyle(base.bodyLarge, scale),
      bodyMedium: _scaleTextStyle(base.bodyMedium, scale),
      bodySmall: _scaleTextStyle(base.bodySmall, scale),
      labelLarge: _scaleTextStyle(base.labelLarge, scale),
      labelMedium: _scaleTextStyle(base.labelMedium, scale),
      labelSmall: _scaleTextStyle(base.labelSmall, scale),
    );
  }
  
  /// Scale individual TextStyle fontSize
  TextStyle? _scaleTextStyle(TextStyle? style, double scale) {
    if (style == null) return null;
    
    final fontSize = style.fontSize;
    if (fontSize == null) return style;
    
    // Apply scale with minimum size enforcement (WCAG AA)
    // Never go below 11px for any text (large text exception)
    final scaledSize = (fontSize * scale).clamp(11.0, double.infinity);
    
    return style.copyWith(fontSize: scaledSize);
  }
}
