# TODO - Standardisation Typographique + Dark Theme + WCAG AA

**Effort estimé total:** 32-42h  
**Date de début:** 31 janvier 2026  
**Stratégie:** Migration incrémentale en 10 PRs atomiques

---

## PHASE 1: FONDATIONS (8-12h)

### ✅ PR1: Architecture themes/ + TODO.md + deprecated aliases
- [x] Créer TODO.md
- [ ] Créer lib/themes/color_schemes.dart (ColorSchemes WCAG AA validés)
- [ ] Créer lib/themes/text_themes.dart (MD3 scale + fontFamilyFallback)
- [ ] Créer lib/themes/app_theme.dart (factory light/dark)
- [ ] Créer lib/themes/app_gradients.dart (brightness-aware)
- [ ] Créer lib/themes/chart_colors.dart (forBrightness method)
- [ ] Ajouter @Deprecated aliases dans lib/app_theme.dart existant
- [ ] Tests: Vérifier ColorScheme contrast ratios ≥4.5:1

### ⏳ PR2: Provider root + ResponsiveWrapper + Consumer sélectif
- [ ] Ajouter `provider: ^6.1.1` dans pubspec.yaml
- [ ] Créer lib/providers/theme_provider.dart (ChangeNotifier + SharedPreferences)
- [ ] Créer lib/utils/responsive_wrapper.dart (LayoutBuilder scale 0.85→1.0→1.2)
- [ ] Modifier main.dart: ChangeNotifierProvider root dans runApp()
- [ ] Modifier main.dart: Consumer<ThemeProvider> autour MaterialApp.themeMode uniquement
- [ ] Tests: Hot reload stability, rebuild sélectif

### ⏳ PR3: Glassmorphism dark + tests WCAG + pre-commit
- [ ] Modifier lib/glassmorphic_dialog.dart: blur conditionnel (dark=0, light=10)
- [ ] Modifier glassmorphic_dialog.dart: colors → colorScheme.surface
- [ ] Créer test/accessibility/contrast_test.dart (formule luminance)
- [ ] Créer test/accessibility/responsive_test.dart (3 scales validation)
- [ ] Créer .git/hooks/pre-commit (flutter test + analyze)
- [ ] Tests: Valider WCAG AA sur tous ColorSchemes

---

## PHASE 2: MIGRATION FICHIERS (16-20h)

### ⏳ PR4: insights_page colors migration (40+ occurrences)
- [ ] insights_page.dart: Colors.black87 → colorScheme.onSurface
- [ ] insights_page.dart: Colors.grey[300] → surfaceVariant
- [ ] insights_page.dart: Colors.white → surface
- [ ] insights_page.dart: AppColors.textSecondary → onSurfaceVariant
- [ ] Tests: Widget tests behavior unchanged light mode
- [ ] Merge strategy dans main (historique clair)

### ⏳ PR5: insights_page TextStyle migration (16 occurrences)
- [ ] insights_page.dart L601: GoogleFonts.poppins(20) → textTheme.headlineMedium
- [ ] insights_page.dart L1032: AppBar title + LayoutBuilder responsive (18/20px)
- [ ] insights_page.dart L1634: fontSize 10 → labelSmall (12px WCAG min)
- [ ] insights_page.dart: 16 TextStyle() → textTheme.* appropriés
- [ ] Tests: Responsive fontSize sur 320/414/600px
- [ ] Merge strategy

### ⏳ PR6: insights_page charts responsive + theme colors
- [ ] insights_page.dart L1714-1780: PieChart → AppChartColors.forBrightness()
- [ ] insights_page.dart: PieChart LayoutBuilder radius 50/40 mobile
- [ ] insights_page.dart: Chart labels fontSize 11px min (WCAG)
- [ ] insights_page.dart L2073: Titre avec Flexible + fontSize 15
- [ ] insights_page.dart: LineChart/BarChart même traitement
- [ ] Tests: Charts light/dark validation visuelle
- [ ] Merge strategy

### ⏳ PR7: main.dart migration + wrapper intégration
- [ ] main.dart: Remplacer 19 TextStyle() → textTheme.*
- [ ] main.dart: Wrapper app avec ResponsiveWrapper
- [ ] main.dart: MaterialApp.theme/darkTheme connecter AppTheme.light()/dark()
- [ ] main.dart: Consumer<ThemeProvider> builder autour themeMode uniquement
- [ ] main.dart: debugPrintRebuildDirtyWidgets: true en dev (si hot reload issues)
- [ ] Tests: Theme switching, hot reload stability
- [ ] Merge strategy

### ⏳ PR8: vertical_timeline colors + bandes themées
- [ ] vertical_timeline_page.dart: 15 colors → colorScheme properties
- [ ] vertical_timeline_page.dart: Colors.indigo.shade400 → primary
- [ ] vertical_timeline_page.dart: Bandes Colors.grey.shade50/white → surfaceVariant/surface
- [ ] vertical_timeline_page.dart: Graduations colors themés
- [ ] vertical_timeline_page.dart: Shadows adaptatifs brightness
- [ ] Tests: Timeline light/dark validation
- [ ] Merge strategy

### ⏳ PR9: Dialogs batch migration (4 fichiers)
- [ ] meal_composer_dialog.dart L668: Tabs fontSize adaptatif
- [ ] meal_composer_dialog.dart: Gradients → AppGradients.meal(brightness)
- [ ] symptom_dialog.dart: Zones colors + gradients themés
- [ ] stool_entry_dialog.dart: Bristol colors WCAG validés
- [ ] event_search_delegate.dart: 6 TextStyle → textTheme
- [ ] Tests: 320px width validation tous dialogs
- [ ] Merge strategy

---

## PHASE 3: VALIDATION & POLISH (8-10h)

### ⏳ PR10: Settings toggle + validation + cleanup deprecated
- [ ] settings_page.dart: Nouvelle section "Apparence"
- [ ] settings_page.dart: SegmentedButton<ThemeMode> (☀️ Light / 🌙 Dark / 🔄 Auto)
- [ ] settings_page.dart: Connecter context.read<ThemeProvider>().setThemeMode()
- [ ] Validation émulateurs: 320px, 414px, 600px light/dark
- [ ] Screenshots: /docs/typography-refactor/ (before/after)
- [ ] Grep search: Vérifier aucun usage AppColors.textPrimary restant
- [ ] Retirer @Deprecated aliases dans lib/app_theme.dart
- [ ] Tests: Validation complète accessibilité + responsive
- [ ] Merge strategy final

---

## NOTES TECHNIQUES

### Échelle Responsive
- **320px:** scale 0.85 (petits phones)
- **375px:** scale 1.0 (baseline iPhone)
- **414px:** scale 1.1 (grands phones)
- **600px+:** scale 1.2 (tablettes)

### WCAG AA Standards
- **Normal text (<18px):** 4.5:1 minimum
- **Large text (≥18px):** 3:1 minimum
- **UI components:** 3:1 minimum

### Material Design 3 Type Scale
- displayLarge: 36px Poppins w600
- displayMedium: 28px Poppins w700 (AppBar)
- displaySmall: 24px Poppins w700 (Dialogs)
- headlineLarge: 22px Poppins w600 (Events)
- headlineMedium: 20px Poppins w600 (Sections)
- headlineSmall: 18px Poppins w600 (Subsections)
- titleLarge: 16px Inter w600 (Lists)
- titleMedium: 14px Inter w600 (Dense headers)
- titleSmall: 12px Inter w600 (Compact labels)
- bodyLarge: 16px Inter (Main content)
- bodyMedium: 14px Inter (Standard text)
- bodySmall: 12px Inter (Metadata)
- labelLarge: 14px Inter w500 (Buttons)
- labelMedium: 12px Inter w500 (Form labels)
- labelSmall: 11px Inter (Chart labels)

### Glassmorphism Dark Mode
- `sigmaX/sigmaY: brightness == Brightness.dark ? 0 : 10`
- Désactive blur en dark mode pour performance
- Colors toujours via `colorScheme.surface.withValues(alpha)`

### Git Strategy
- **Merge** (pas rebase) pour historique clair
- Pre-commit hook: `flutter test test/accessibility/ && flutter analyze`
- Branches: `feature/pr1-themes-architecture`, `feature/pr2-provider`, etc.

---

## PROGRESSION

**Phase 1:** ⏳ 0/3 PRs  
**Phase 2:** ⏳ 0/6 PRs  
**Phase 3:** ⏳ 0/1 PR  

**TOTAL:** ⏳ 0/10 PRs (0%)
