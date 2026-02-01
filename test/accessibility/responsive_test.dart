import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crohnicles/themes/app_theme.dart' as themes;
import 'package:crohnicles/utils/responsive_wrapper.dart';

/// Responsive Text Scaling Tests
/// 
/// Validates that text scales correctly across different screen widths:
/// - 320px: 0.85 scale (small phones like iPhone SE)
/// - 375px: 1.0 scale (baseline - standard phones)
/// - 414px: 1.05 scale (large phones like iPhone Pro Max)
/// - 600px: 1.2 scale (tablets like iPad Mini)
/// 
/// Also validates minimum font size enforcement (11px WCAG minimum)

void main() {
  group('Responsive Text Scaling', () {
    testWidgets('320px width scales down to 0.85', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      
      await tester.pumpWidget(
        MaterialApp(
          theme: themes.AppTheme.light(),
          home: ResponsiveWrapper(
            child: Builder(
              builder: (context) {
                final textTheme = Theme.of(context).textTheme;
                
                // displayMedium base: 28px → 28 * 0.85 = 23.8px
                expect(
                  textTheme.displayMedium?.fontSize,
                  closeTo(23.8, 0.5),
                  reason: 'displayMedium should scale down on small screens',
                );
                
                // bodyMedium base: 14px → 14 * 0.85 = 11.9px
                expect(
                  textTheme.bodyMedium?.fontSize,
                  closeTo(11.9, 0.5),
                  reason: 'bodyMedium should scale down',
                );
                
                // labelSmall base: 11px → should stay 11px (minimum WCAG)
                expect(
                  textTheme.labelSmall?.fontSize,
                  greaterThanOrEqualTo(11.0),
                  reason: 'No text should go below 11px (WCAG minimum)',
                );
                
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });
    
    testWidgets('375px width maintains 1.0 scale (baseline)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 667));
      
      await tester.pumpWidget(
        MaterialApp(
          theme: themes.AppTheme.light(),
          home: ResponsiveWrapper(
            child: Builder(
              builder: (context) {
                final textTheme = Theme.of(context).textTheme;
                
                // displayMedium base: 28px → 28 * 1.0 = 28px
                expect(
                  textTheme.displayMedium?.fontSize,
                  closeTo(28.0, 0.5),
                  reason: 'displayMedium should be baseline size',
                );
                
                // bodyMedium base: 14px → 14 * 1.0 = 14px
                expect(
                  textTheme.bodyMedium?.fontSize,
                  closeTo(14.0, 0.5),
                  reason: 'bodyMedium should be baseline size',
                );
                
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });
    
    testWidgets('414px width scales to ~1.05', (tester) async {
      await tester.binding.setSurfaceSize(const Size(414, 896));
      
      await tester.pumpWidget(
        MaterialApp(
          theme: themes.AppTheme.light(),
          home: ResponsiveWrapper(
            child: Builder(
              builder: (context) {
                final textTheme = Theme.of(context).textTheme;
                
                // displayMedium base: 28px → 28 * ~1.02 = ~28.5px
                expect(
                  textTheme.displayMedium?.fontSize,
                  greaterThanOrEqualTo(28.0),
                  reason: 'displayMedium should scale slightly up on large phones',
                );
                
                expect(
                  textTheme.displayMedium?.fontSize,
                  lessThan(30.0),
                  reason: 'displayMedium should not exceed reasonable bounds',
                );
                
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });
    
    testWidgets('600px width scales up to 1.2 (tablet)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 800));
      
      await tester.pumpWidget(
        MaterialApp(
          theme: themes.AppTheme.light(),
          home: ResponsiveWrapper(
            child: Builder(
              builder: (context) {
                final textTheme = Theme.of(context).textTheme;
                
                // displayMedium base: 28px → 28 * 1.2 = 33.6px
                expect(
                  textTheme.displayMedium?.fontSize,
                  closeTo(33.6, 1.0),
                  reason: 'displayMedium should scale up on tablets',
                );
                
                // bodyMedium base: 14px → 14 * 1.2 = 16.8px
                expect(
                  textTheme.bodyMedium?.fontSize,
                  closeTo(16.8, 1.0),
                  reason: 'bodyMedium should scale up on tablets',
                );
                
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });
    
    testWidgets('Dark theme maintains same scaling', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      
      await tester.pumpWidget(
        MaterialApp(
          theme: themes.AppTheme.dark(),
          home: ResponsiveWrapper(
            child: Builder(
              builder: (context) {
                final textTheme = Theme.of(context).textTheme;
                
                // Same scaling should apply in dark mode
                expect(
                  textTheme.displayMedium?.fontSize,
                  closeTo(23.8, 0.5),
                  reason: 'Dark theme should have same scaling as light',
                );
                
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });
  });
  
  group('Minimum Font Size Enforcement', () {
    testWidgets('No font size below 11px at any scale', (tester) async {
      final screenWidths = [280, 320, 360, 375, 414, 600, 800];
      
      for (final width in screenWidths) {
        await tester.binding.setSurfaceSize(Size(width.toDouble(), 600));
        
        await tester.pumpWidget(
          MaterialApp(
            theme: themes.AppTheme.light(),
            home: ResponsiveWrapper(
              child: Builder(
                builder: (context) {
                  final textTheme = Theme.of(context).textTheme;
                  
                  // Check all text styles
                  final styles = [
                    textTheme.displayLarge,
                    textTheme.displayMedium,
                    textTheme.displaySmall,
                    textTheme.headlineLarge,
                    textTheme.headlineMedium,
                    textTheme.headlineSmall,
                    textTheme.titleLarge,
                    textTheme.titleMedium,
                    textTheme.titleSmall,
                    textTheme.bodyLarge,
                    textTheme.bodyMedium,
                    textTheme.bodySmall,
                    textTheme.labelLarge,
                    textTheme.labelMedium,
                    textTheme.labelSmall,
                  ];
                  
                  for (final style in styles) {
                    if (style?.fontSize != null) {
                      expect(
                        style!.fontSize!,
                        greaterThanOrEqualTo(11.0),
                        reason: 'Font size ${style.fontSize} at ${width}px width '
                            'should be ≥11px (WCAG AA minimum)',
                      );
                    }
                  }
                  
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
      }
    });
  });
  
  group('ResponsiveWrapper Edge Cases', () {
    testWidgets('Handles very small screens gracefully', (tester) async {
      await tester.binding.setSurfaceSize(const Size(280, 500));
      
      await tester.pumpWidget(
        MaterialApp(
          theme: themes.AppTheme.light(),
          home: ResponsiveWrapper(
            child: Builder(
              builder: (context) {
                final textTheme = Theme.of(context).textTheme;
                
                // Should apply minimum scale (0.85)
                expect(
                  textTheme.displayMedium?.fontSize,
                  lessThanOrEqualTo(28.0 * 0.85 + 1),
                  reason: 'Very small screens should use minimum scale',
                );
                
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });
    
    testWidgets('Handles very large screens gracefully', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      
      await tester.pumpWidget(
        MaterialApp(
          theme: themes.AppTheme.light(),
          home: ResponsiveWrapper(
            child: Builder(
              builder: (context) {
                final textTheme = Theme.of(context).textTheme;
                
                // Should cap at maximum scale (1.2)
                expect(
                  textTheme.displayMedium?.fontSize,
                  closeTo(28.0 * 1.2, 1.0),
                  reason: 'Very large screens should use maximum scale',
                );
                
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });
  });
}
