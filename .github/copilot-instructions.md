# Crohnicles Project Instructions

## Project Overview
"Crohnicles" is a Flutter application for tracking health events (IBD/Crohn's) with a "Local First" architecture using SQLite.
**Stack:** Flutter (Material 3), Dart, sqflite (Storage), fl_chart (Viz), intl, mobile_scanner, HTTP (OpenFoodFacts API).

## Architecture & Core Components

### Data Layer (lib/database_helper.dart)
- **Thread-Safe Singleton:** Uses `Completer<Database>` pattern to prevent race conditions during initialization
  - Multiple simultaneous `database` getter calls await the same Future
  - Critical: Pass `db` parameter to `cleanOldCache()` during initialization to avoid recursive calls
- **Tables:**
  - `events`: Central log. Uses `meta_data` (JSON) to store complex structures (e.g. list of food items).
  - `foods`: Local database for autocomplete. Seeded with 25+ basic items initially.
  - `products_cache`: OpenFoodFacts cache (barcode → FoodModel, 90-day TTL).
- **Dates:** Stored as **ISO8601 Strings** (YYYY-MM-DDTHH:MM:SS).
- **Queries:** Contains raw SQL for analytics (getPainEvolution, getStoolFrequency).
- **Logging:** All operations log with `[DB]` prefix for debugging.

### Models
- **lib/event_model.dart**: Immutable class representing a unified timeline event.
  - EventType: meal, symptom, stool, daily_checkup.
  - Properties: tags (List<String>), meta_data (JSON String), severity (0-10).
- **lib/food_model.dart**: Represents an ingredient/food item with category, tags, and optional nutrition data (proteins, fats, carbs, fiber, sugars, brand, imageUrl, barcode).

### UI Structure & Navigation
- **Entry Point (lib/main.dart):** Holds the main TimelinePage and global _addEvent logic.
- **Composer Pattern:** Complex inputs are decoupled into "Composer" dialogs:
  - **Meal:** lib/meal_composer_dialog.dart (3-tab interface: Scanner/Search/Create, Cart system, internal Repas/Snack state).
  - **Symptom:** lib/symptom_dialog.dart (Hierarchical drill-down: Abdomen grid + detailed categories).
  - **Stool:** lib/stool_entry_dialog.dart (Bristol scale 1-7 using Wrap for all-visible layout).
- **Analysis:** lib/insights_page.dart uses fl_chart to visualize SQL aggregation results.
- **Services:** lib/services/off_service.dart handles OpenFoodFacts API integration with 90-day caching.

### Design System (lib/app_theme.dart)
- **Gradient-based:** Each event type has Start/End colors (mealStart/mealEnd, painStart/painEnd, etc.)
- **Material 3:** Uses google_fonts (Poppins for headers, Inter for body).
- **Glassmorphism:** Dialogs use semi-transparent backgrounds with blur effects.

## Key Developer Workflows

### 1. Adding a New Event Type
1. Define type in EventType enum (event_model.dart).
2. Create a specialized Dialog Widget (return Map<String, dynamic>).
3. Add launch button in _showAddMenu (main.dart).
4. Handle the result in the dialog's callback to call _addEvent.
5. Add a specific Card widget (_buildXCard) in TimelinePage.

### 2. Modifying Database Schema
1. Increment `_version` in _initDatabase.
2. Add migration logic in _onUpgrade (e.g., ALTER TABLE...).
3. **Never** rename columns; only add new ones or create new tables.
4. **Critical:** Pass `db` parameter to any functions called during schema changes to avoid "database is locked" errors.

### 3. Working with Charts (insights_page.dart)
- **Data Source:** Always fetch specific aggregations from DatabaseHelper (avoid processing all events in Dart if possible).
- **Formatting:** Convert SQL dates to relative X-values (e.g., "Day 0" to "Day 30").
- **Styling:** Use LineChart for trends (Pain) and BarChart for counts (Stools).

### 4. Dialog UI Development
- **Hot Reload:** Use `flutter run -d windows` and press `r` for hot reload after changes.
- **Desktop Simulators:** Windows simulator has limited scroll support:
  - **Avoid:** Horizontal `SingleChildScrollView` (scroll doesn't work with mouse).
  - **Use:** `Wrap` widget for small lists (Bristol scale), `ListView` for vertical lists.
- **Layout Constraints:** Use `constraints: BoxConstraints(maxHeight: X)` instead of fixed `height` to prevent overflow.
- **Tab Styling:** Match TabBar style across dialogs (see meal_composer_dialog.dart vs symptom_dialog.dart):
  - No `borderRadius` on indicator (causes hidden tabs).
  - Use bottom border (3px) + subtle gradient background (scale 0.15).
  - Ensure both selected/unselected label colors are visible (not white-on-white).

## Conventions & Patterns

### Dialogs
- **Return Raw Data:** Map or List via Navigator.pop (include `is_snack` key for meals).
- **No Direct DB Writes:** Unless self-contained (e.g., creating new food in autocomplete).
- **Layout:** Use `SizedBox(width: double.maxFinite)` in AlertDialog content to prevent overflow.
- **State Management:** Use internal state (e.g., `_isSnack` in MealComposerDialog) instead of constructor parameters for dialog-internal choices.

### Images & Icons
- **Image Picker:** Use image_picker package.
- **Desktop Fix:** Explicitly handle Windows/Linux file paths (copy to AppDocumentsDirectory).
- **Icons:** Prefer **Material Icons** (Icons.local_drink) over Emojis for cross-platform rendering (especially Windows).

### Styling & Theming
- **Gradient Access:** AppColors.mealGradient, AppColors.painGradient, etc.
- **Color Scales:** Use `.scale(0.2)` for subtle backgrounds, `.withValues(alpha: 0.3)` for transparency.
- **Shadows:** Add text shadows for readability on gradients (see symptom_dialog title).

### Data Conventions
- **Tagging:** Auto-tagging logic (e.g., "Pâtes" → adds "Féculent" tag) happens at Entry level (MealComposerDialog).
- **JSON Storage:** Use `jsonEncode()` for complex data in `meta_data` field.
- **Result Keys:** Consistent naming: `foods`, `tags`, `is_snack`, `severity`, `zones`.

## Common Tasks Reference
- **Seed Data:** DatabaseHelper._seedFoods handles initial 25-item population.
- **Event Search:** EventSearchDelegate (lib/event_search_delegate.dart) implements native search.
- **Platform Init:** sqflite FFI initialization for Web/Desktop is in main().
- **Barcode Scanning:** mobile_scanner package with OFFService integration (requires camera permissions in AndroidManifest.xml/Info.plist).
- **Formatting:** Always run `dart format <file>` before committing (VSCode auto-formats on save).

## Analytics & Correlation Patterns

### Suspect Ingredients Analysis
- **Pattern:** 90-day lookback window to correlate foods with symptoms
- **Method:** `getSuspectIngredients()` - Count symptom occurrences within 4-8h after meals
- **Algorithm:**
  1. Query all meals in last 90 days with JSON food data
  2. For each food, count symptoms within time window
  3. Calculate frequency ratio (symptom_count / total_occurrences)
  4. Return foods with ratio > threshold (e.g., 0.3 = 30% correlation)

### Nutritional Trends
- **Pattern:** Aggregate nutrition data over time periods (week, month)
- **Method:** `getAverageNutrition(startDate, endDate)` 
- **Fields:** Average proteins, fats, carbs, fiber, sugars per day
- **Visualization:** Use fl_chart BarChart for macro comparison

### HeatMap Visualization
- **Pattern:** 2D grid showing ingredient × time-of-day symptom frequency
- **Data Structure:**
  ```dart
  Map<String, Map<int, int>> // ingredient → {hour → count}
  ```
- **Use Case:** Identify problematic foods at specific meal times (breakfast, lunch, dinner)

## Mobile Deployment

### Android Build
1. **Camera Permissions:** Add to `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <uses-permission android:name="android.permission.CAMERA" />
   <uses-feature android:name="android.hardware.camera" android:required="false" />
   ```

2. **Build Commands:**
   ```bash
   flutter build apk --release              # Single APK
   flutter build appbundle --release        # App Bundle for Play Store
   flutter build apk --split-per-abi        # Separate APKs per architecture
   ```

3. **Testing on Emulator:**
   ```bash
   flutter emulators --launch <emulator-id>
   flutter run -d emulator-5554
   ```

### iOS Build
1. **Camera Permissions:** Add to `ios/Runner/Info.plist`:
   ```xml
   <key>NSCameraUsageDescription</key>
   <string>Crohnicles needs camera access to scan product barcodes</string>
   ```

2. **Build Commands:**
   ```bash
   flutter build ios --release              # Build IPA
   flutter build ipa --export-method ad-hoc # Ad-hoc distribution
   ```

3. **Signing:** Configure in Xcode:
   - Open `ios/Runner.xcworkspace`
   - Select Runner target → Signing & Capabilities
   - Set Team and Bundle Identifier

4. **Testing on Simulator:**
   ```bash
   open -a Simulator
   flutter run -d <device-id>
   ```

### Platform-Specific Considerations
- **Windows:** Development environment, use `flutter run -d windows` for testing
- **Android:** Min SDK 21 (Android 5.0), Target SDK 34
- **iOS:** Deployment target iOS 12.0+

## Testing Strategy

### Test Structure
```
test/
├── database_helper_test.dart       # DB operations, concurrency
├── models/
│   ├── event_model_test.dart       # Serialization, immutability
│   └── food_model_test.dart        # Nutrition data, tags
└── widgets/
    └── meal_composer_dialog_test.dart  # Widget & golden tests
```

### Running Tests
```bash
flutter test                         # All tests
flutter test test/database_helper_test.dart  # Specific file
flutter test --coverage             # With coverage report
flutter test --update-goldens       # Regenerate golden files
```

### Test Data Patterns
- **Realistic IBD Data:** Use common French foods (Pâtes, Poulet, Fromage)
- **Symptom Events:** Severity 1-10, realistic time gaps (4-8h after meals)
- **Bristol Scale:** Types 1-7 with appropriate tags (Constipation, Diarrhée)

### Golden Tests
- **Purpose:** Ensure dialog UI consistency across updates
- **Location:** `test/goldens/` (auto-generated)
- **Update:** Run `flutter test --update-goldens` after intentional UI changes

## Advanced Patterns

### Large File Refactoring
- **Problem:** Files >1000 lines, complex nested structures
- **Solution:**
  1. Create new builder methods at end of class first
  2. Use `grep_search` to detect code duplication
  3. Break large replacements into smaller, targeted edits
  4. Format with `dart format` before checking errors

### Dialog State Management
- **Pattern:** Internal state for dialog-specific choices
- **Example:** `_isSnack` in MealComposerDialog instead of constructor parameter
- **Why:** Allows user to change selection without reopening dialog

### Hot Reload Limitations
- **Full Restart Required:**
  - Mixin changes (e.g., adding SingleTickerProviderStateMixin)
  - Database schema changes
  - New asset files
- **Shortcut:** Press `R` in terminal (capital R, not lowercase r)

## Debugging Tips
- **Database Locks:** If "database is locked (code 5)" appears, check for concurrent initialization calls. Solution: Use the Completer pattern already implemented.
- **Hot Reload Issues:** If changes don't appear, do full restart (press `R` in terminal or rerun `flutter run -d windows`).
- **Layout Overflow:** Use `constraints: BoxConstraints(maxHeight:)` on dialogs, add `SingleChildScrollView` to Column children.
- **Scroll Not Working:** In Windows simulator, use `Wrap` or vertical `ListView` instead of horizontal scroll.
