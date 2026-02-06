# TODO - Crohnicles Development Tasks

**Dernière mise à jour:** 6 février 2026

---

## ✅ COMPLÉTÉ v1.2 (Février 2026)

### 🔒 Sécurité & RGPD (Étapes 1-4)
- [x] **Étape 1 - Compilation et erreurs** : 25 erreurs corrigées
- [x] **Étape 2 - Chiffrement base de données** :
  - Encryption AES-256 SQLCipher avec `sqlcipher_flutter_libs`
  - Toggle dans Settings : Chiffrer/Déchiffrer avec migration automatique
  - Service `EncryptionService` avec génération clé sécurisée (flutter_secure_storage)
  - Test migration : DB unencrypted → encrypted → unencrypted (réversible)
- [x] **Étape 3 - Validation des saisies** :
  - Classe `EventValidators` (10 méthodes)
  - Validations : dates (max 2 ans), sévérité 1-10, Bristol 1-7, quantités >0 et ≤2000g/ml
  - SnackBar rouge standardisée pour erreurs
  - Intégrations : MealComposerDialog, SymptomDialog, StoolEntryDialog
- [x] **Étape 4 - Export CSV + RGPD** :
  - Service `CsvExportService` avec UTF-8 BOM (Excel-compatible)
  - Format : "Date,Type,Titre,Sévérité,Tags,Métadonnées"
  - Partage multi-plateforme via `share_plus` (Android sheet, Desktop Documents)
  - Dialog preview dans Settings avec statistiques (count, taille estimée)

### 🤖 Machine Learning (Étape 5)
- [x] **Étape 5 - ML Training Status UI** :
  - Widget `MLTrainingStatusCard` dans insights_page (1er élément)
  - Méthodes DatabaseHelper : `getMLTrainingStats()`, `getMealCount()`, `getSevereSymptomCount()`
  - Affichage : Progression globale (X/30 repas, X/30 symptômes), dernière date entraînement
  - Couleur dynamique : Vert (prêt ≥30), Orange (50-100%), Gris (<50%)
  - Message aide si données insuffisantes

### 🛠️ Corrections diverses
- [x] **TimePicker format 24h** : MediaQuery.alwaysUse24HourFormat sur tous les pickers

### 🧪 Tests (Étape 7)
- [x] **Étape 7 - Tests critiques** :
  - **test/validation_test.dart** : 49 tests (EventValidators - Étape 3)
    * Date validation : Future dates, 2 years limit
    * Severity/Bristol/Quantity validation : Scale checks, boundaries
    * Required text : 1-200 chars
    * Tags & anatomical zones
    * Integration scenarios
  - **test/csv_export_test.dart** : 40 tests (CsvExportService - Étape 4)
    * CSV format : Header, escaping, UTF-8 BOM
    * EventType conversion (all 5 types)
    * Metadata parsing : Foods, zones, Bristol, weather
    * RGPD compliance verification
  - **test/encryption_test.dart** : Tests (Encryption logic - Étape 2)
    * Key generation : 64 hex chars, uniqueness
    * Migration filenames (backup, encrypted)
    * RGPD deletion file list
  - **test/ml_training_stats_test.dart** : 22 tests (ML Stats - Étape 5)
    * Severity threshold logic (≥5)
    * Readiness calculation (30/30 requirement)
    * Progress calculation (0.0-1.0)
    * SQL query validation
  - **Total : 111 tests unitaires passant** ✅
  - **Note :** Tests DB-dépendants marqués comme integration tests (device-only)

### 🚀 GitHub & CI/CD (Étape 8)
- [x] **Étape 8 - Préparation GitHub** :
  - **flutter analyze** : 194 → 101 issues (93 corrigées, 48% réduction)
    * Remplacement 66 `print()` par `debugPrint()`
    * Suppression deprecated colors (app_theme.dart)
    * Nettoyage imports inutilisés et code mort
  - **GitHub Actions CI/CD** : `.github/workflows/ci.yml`
    * Job Analyze : flutter analyze, dart format, pub outdated
    * Job Test : flutter test --coverage + Codecov
    * Job Build : Android APK, iOS Runner.app, Windows Release
    * Triggers : Push/PR sur main et develop
  - **Configuration validée** :
    * `.gitignore` : .env, build/, .dart_tool/, coverage/
    * `.env.example` : Template OpenWeather API key
    * README.md : Instructions installation complètes

---

## ✅ COMPLÉTÉ v1.1 (Janvier 2026)

### UX & Interface
- [x] Wizard symptômes 3 étapes (Sélection → Intensités → Résumé)
- [x] Silhouette abdomen avec image PNG (Transform.scale + Alignment)
- [x] Regroupement événements par timestamp sur la timeline
- [x] Corrections mode sombre (meal detail dialog, methodology page)
- [x] Amélioration contraste timeline mode clair (surfaceContainerHigh)
- [x] Correction overflow graphique localisation douleurs (Flexible + SingleChildScrollView)

### Architecture & Sécurité
- [x] Sécurisation API OpenWeather avec flutter_dotenv (.env + .gitignore)
- [x] Nettoyage code mort (_buildWeatherCorrelationsBarChart, _buildZoneSeverityRow)
- [x] Suppression imports inutilisés (main.dart)

---

## 🚀 PRIORITÉS v1.3 (Post-Consolidation)

### Option A : Finaliser ML On-Device
**Statut :** ✅ Service d'entraînement implémenté (`lib/ml/training_service.dart`)  
**Restant :**
- [ ] Bouton "🧠 Entraîner Modèle" dans insights_page avec dialog progress
- [ ] Badge "ML Activé" si modèle .tflite existe
- [ ] Tests : Accuracy ≥70%, latence <100ms, memory <50MB

### Option B : Widget Météo Timeline
**Statut :** ⏳ Pas commencé  
**Objectif :** Afficher température/conditions météo dans événements timeline
- [ ] Créer `widget/weather_chip.dart` (icône + température)
- [ ] Intégrer dans `vertical_timeline_page.dart` event cards
- [ ] Cache local données météo (éviter API calls répétés)

### Option C : Export PDF Rapport RGPD
**Statut :** ⏳ Pas commencé  
**Objectif :** Génération PDF complet avec graphiques
- [ ] Utiliser package `pdf: ^3.10.0`
- [ ] Inclure graphiques (fl_chart → image rendering)
- [ ] Format A4 professionnel (header, footer, pagination)
- [ ] Bouton "Exporter PDF" dans Settings (à côté Export CSV)

---

## 📋 REFACTOR ARCHITECTURE (Optionnel)

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
