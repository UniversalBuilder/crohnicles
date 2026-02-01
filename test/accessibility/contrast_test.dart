import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:crohnicles/themes/color_schemes.dart';

/// WCAG AA Contrast Ratio Tests
/// 
/// Validates all ColorScheme combinations meet WCAG 2.1 Level AA standards:
/// - Normal text (<18px or <14px bold): 4.5:1 minimum
/// - Large text (≥18px or ≥14px bold): 3:1 minimum
/// - UI components: 3:1 minimum
/// 
/// Formula: Contrast Ratio = (L1 + 0.05) / (L2 + 0.05)
/// where L1 is the lighter color and L2 is the darker color
/// 
/// Source: https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html

void main() {
  group('WCAG AA Contrast Ratios - Light Theme', () {
    const scheme = AppColorSchemes.light;
    
    test('onSurface on surface meets 4.5:1 (normal text)', () {
      final ratio = _contrastRatio(scheme.onSurface, scheme.surface);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'onSurface (#${_colorToHex(scheme.onSurface)}) on surface '
              '(#${_colorToHex(scheme.surface)}): $ratio:1 (expected ≥4.5:1)');
    });
    
    test('onSurfaceVariant on surface meets 4.5:1 (normal text)', () {
      final ratio = _contrastRatio(scheme.onSurfaceVariant, scheme.surface);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'onSurfaceVariant (#${_colorToHex(scheme.onSurfaceVariant)}) on surface '
              '(#${_colorToHex(scheme.surface)}): $ratio:1 (expected ≥4.5:1)');
    });
    
    test('primary on onPrimary meets 4.5:1', () {
      final ratio = _contrastRatio(scheme.primary, scheme.onPrimary);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'primary on onPrimary: $ratio:1 (expected ≥4.5:1)');
    });
    
    test('secondary on onSecondary meets 4.5:1', () {
      final ratio = _contrastRatio(scheme.secondary, scheme.onSecondary);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'secondary on onSecondary: $ratio:1 (expected ≥4.5:1)');
    });
    
    test('tertiary on onTertiary meets 4.5:1', () {
      final ratio = _contrastRatio(scheme.tertiary, scheme.onTertiary);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'tertiary on onTertiary: $ratio:1 (expected ≥4.5:1)');
    });
    
    test('error on onError meets 4.5:1', () {
      final ratio = _contrastRatio(scheme.error, scheme.onError);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'error on onError: $ratio:1 (expected ≥4.5:1)');
    });
    
    test('onPrimaryContainer on primaryContainer meets 4.5:1', () {
      final ratio = _contrastRatio(scheme.onPrimaryContainer, scheme.primaryContainer);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'onPrimaryContainer on primaryContainer: $ratio:1 (expected ≥4.5:1)');
    });
    
    test('outline on surface meets 3:1 (UI components)', () {
      final ratio = _contrastRatio(scheme.outline, scheme.surface);
      expect(ratio, greaterThanOrEqualTo(3.0),
          reason: 'outline on surface: $ratio:1 (expected ≥3:1 for UI)');
    });
  });
  
  group('WCAG AA Contrast Ratios - Dark Theme', () {
    const scheme = AppColorSchemes.dark;
    
    test('onSurface on surface meets 4.5:1 (normal text)', () {
      final ratio = _contrastRatio(scheme.onSurface, scheme.surface);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'onSurface (#${_colorToHex(scheme.onSurface)}) on surface '
              '(#${_colorToHex(scheme.surface)}): $ratio:1 (expected ≥4.5:1)');
    });
    
    test('onSurfaceVariant on surface meets 4.5:1 (normal text)', () {
      final ratio = _contrastRatio(scheme.onSurfaceVariant, scheme.surface);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'onSurfaceVariant (#${_colorToHex(scheme.onSurfaceVariant)}) on surface '
              '(#${_colorToHex(scheme.surface)}): $ratio:1 (expected ≥4.5:1)');
    });
    
    test('primary on onPrimary meets 4.5:1', () {
      final ratio = _contrastRatio(scheme.primary, scheme.onPrimary);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'primary on onPrimary: $ratio:1 (expected ≥4.5:1)');
    });
    
    test('secondary on onSecondary meets 4.5:1', () {
      final ratio = _contrastRatio(scheme.secondary, scheme.onSecondary);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'secondary on onSecondary: $ratio:1 (expected ≥4.5:1)');
    });
    
    test('tertiary on onTertiary meets 4.5:1', () {
      final ratio = _contrastRatio(scheme.tertiary, scheme.onTertiary);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'tertiary on onTertiary: $ratio:1 (expected ≥4.5:1)');
    });
    
    test('error on onError meets 4.5:1', () {
      final ratio = _contrastRatio(scheme.error, scheme.onError);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'error on onError: $ratio:1 (expected ≥4.5:1)');
    });
    
    test('outline on surface meets 3:1 (UI components)', () {
      final ratio = _contrastRatio(scheme.outline, scheme.surface);
      expect(ratio, greaterThanOrEqualTo(3.0),
          reason: 'outline on surface: $ratio:1 (expected ≥3:1 for UI)');
    });
  });
  
  group('Contrast Ratio Calculation Validation', () {
    test('White on black should be 21:1', () {
      final ratio = _contrastRatio(Colors.white, Colors.black);
      expect(ratio, closeTo(21.0, 0.1),
          reason: 'White on black is maximum contrast (21:1)');
    });
    
    test('Black on white should be 21:1', () {
      final ratio = _contrastRatio(Colors.black, Colors.white);
      expect(ratio, closeTo(21.0, 0.1),
          reason: 'Order should not matter');
    });
    
    test('Same color should be 1:1', () {
      final ratio = _contrastRatio(Colors.grey, Colors.grey);
      expect(ratio, closeTo(1.0, 0.01),
          reason: 'Same color has no contrast');
    });
  });
}

/// Calculate WCAG 2.1 contrast ratio between two colors
/// 
/// Formula: (L1 + 0.05) / (L2 + 0.05)
/// where L1 is relative luminance of lighter color
/// and L2 is relative luminance of darker color
double _contrastRatio(Color color1, Color color2) {
  final lum1 = _relativeLuminance(color1);
  final lum2 = _relativeLuminance(color2);
  
  final lighter = max(lum1, lum2);
  final darker = min(lum1, lum2);
  
  return (lighter + 0.05) / (darker + 0.05);
}

/// Calculate relative luminance of a color
/// 
/// Formula from WCAG 2.1:
/// L = 0.2126 * R + 0.7152 * G + 0.0722 * B
/// where R, G, B are normalized and gamma-corrected
double _relativeLuminance(Color color) {
  final r = _gammaCorrect(color.red / 255.0);
  final g = _gammaCorrect(color.green / 255.0);
  final b = _gammaCorrect(color.blue / 255.0);
  
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// Apply gamma correction to RGB component
/// 
/// Formula from WCAG 2.1:
/// if RsRGB ≤ 0.03928 then R = RsRGB/12.92
/// else R = ((RsRGB+0.055)/1.055)^2.4
double _gammaCorrect(double value) {
  if (value <= 0.03928) {
    return value / 12.92;
  } else {
    return pow((value + 0.055) / 1.055, 2.4).toDouble();
  }
}

/// Convert Color to hex string for debugging
String _colorToHex(Color color) {
  return '${color.red.toRadixString(16).padLeft(2, '0')}'
      '${color.green.toRadixString(16).padLeft(2, '0')}'
      '${color.blue.toRadixString(16).padLeft(2, '0')}'.toUpperCase();
}
