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
  - **Meal:** lib/meal_composer_dialog.dart (4-tab interface: Scanner/Search/Create/Cart, Cart system with AutomaticKeepAliveClientMixin, internal Repas/Snack state).
  - **Symptom:** lib/symptom_dialog.dart (Hierarchical drill-down: Abdomen grid + detailed categories).
  - **Stool:** lib/stool_entry_dialog.dart (Bristol scale 1-7 using Wrap for all-visible layout).
- **Analysis:** lib/insights_page.dart uses fl_chart to visualize SQL aggregation results.
- **Services:** lib/services/off_service.dart handles OpenFoodFacts API integration with 90-day caching.
- **Meal Detail View:** Single tap on meal card opens read-only detail dialog, long-press for edit/delete menu.

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
5. **UPDATE Operations:** Always remove `id` field before UPDATE to avoid "datatype mismatch" errors:
   ```dart
   final updateData = Map<String, dynamic>.from(data);
   updateData.remove('id');
   await db.update('table', updateData, where: 'id = ?', whereArgs: [id]);
   ```

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
- **Meal meta_data Format:** Always wrap food arrays in object: `jsonEncode({'foods': [...]})`
  - **CORRECT:** `meta_data: jsonEncode({'foods': [food1, food2]})`
  - **WRONG:** `meta_data: jsonEncode([food1, food2])` (breaks editing)
- **Tag Recalculation:** When adding/removing items from cart, recalculate global tags by iterating all cart items.

## Common Tasks Reference
- **Seed Data:** DatabaseHelper._seedFoods handles initial 25-item population.
- **Event Search:** EventSearchDelegate (lib/event_search_delegate.dart) implements native search.
- **Platform Init:** sqflite FFI initialization for Web/Desktop is in main().
- **Barcode Scanning:** mobile_scanner package with OFFService integration (requires camera permissions in AndroidManifest.xml/Info.plist).
- **Formatting:** Always run `dart format <file>` before committing (VSCode auto-formats on save).
- **OFF Product Enrichment:** `enrichWithPopularOFFProducts()` fetches 24 diverse products (breakfast, proteins, starches, vegetables, dairy, drinks, snacks) for realistic demo data.
- **Demo Data Generation:** `generateDemoData()` groups foods by meal type (breakfast: 8h, lunch: 12h30, dinner: 19h30) for realistic combinations instead of random pairings.

## OpenFoodFacts Integration (lib/services/off_service.dart)

### Category Classification Logic
Products are categorized by checking `categories_tags` in priority order:
1. **Bread/Spreads** (pain, confiture, jam) → `Féculent` or `Snack`
2. **Starches** (pasta, rice, céréales) → `Féculent`
3. **Proteins** (meat, fish, poulet) → `Protéine`
4. **Dairy** (laitier, yaourt) → `Snack`
5. **Meals** (pizza, plat, sandwich) → `Repas`
6. **Beverages** (beverage, boisson, drink) → `Boisson` (checked last to avoid over-categorizing)

**Critical:** Check specific categories (bread, spreads) BEFORE generic ones (beverage) to avoid mis-categorization (e.g., "Pain" marked as "Boisson").

### API Endpoints
- **Search:** `https://world.openfoodfacts.org/cgi/search.pl` (CGI endpoint, not v2)
- **Barcode:** `https://world.openfoodfacts.org/api/v2/product/{barcode}`
- **Caching:** 90-day TTL in `products_cache` table to minimize API calls

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
- **Cart Tab Pattern:** Use separate StatefulWidget with `AutomaticKeepAliveClientMixin` to preserve cart state when switching tabs:
  ```dart
  class _CartTabContent extends StatefulWidget with AutomaticKeepAliveClientMixin {
    @override
    bool get wantKeepAlive => true;
    // ... cart display logic
  }
  ```

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
- **Scroll Not Working:** In Windows simulator, use `Wrap` or vertical `ListView` instead of horizontal scroll.- **"Looking up a deactivated widget's ancestor"**: This error occurs when trying to access BuildContext after widget disposal. Common causes:
  - Async operations continuing after Navigator.pop()
  - Using context in callbacks after unmount
  - **Solution:** Check `if (mounted)` before any setState() or Navigator operations in async methods
  - **Example:**
    ```dart
    Future<void> _loadData() async {
      final data = await fetchData();
      if (!mounted) return; // Critical check
      setState(() => _data = data);
    }
    ```

## Testing Patterns

### Widget Testing for Cart Tab
The Cart tab uses `AutomaticKeepAliveClientMixin` which requires special testing considerations:

```dart
testWidgets('Cart tab preserves state when switching tabs', (WidgetTester tester) async {
  // Wrap in AutomaticKeepAliveClientMixin compatible ancestor
  await tester.pumpWidget(MaterialApp(
    home: DefaultTabController(
      length: 4,
      child: Scaffold(
        body: TabBarView(
          children: [
            _buildScannerTab(),
            _buildSearchTab(),
            _buildCreateTab(),
            _CartTabContent(cart: testCart, onRemove: mockRemove),
          ],
        ),
      ),
    ),
  ));

  // Switch away and back to verify state persistence
  await tester.tap(find.byIcon(Icons.search));
  await tester.pumpAndSettle();
  
  await tester.tap(find.byIcon(Icons.shopping_cart));
  await tester.pumpAndSettle();
  
  // Verify cart items still present
  expect(find.text('Test Food'), findsOneWidget);
});
```

### Testing Async Dialog Workflows
Meal composer returns Map<String, dynamic> asynchronously:

```dart
testWidgets('Meal composer validates and returns data', (WidgetTester tester) async {
  Map<String, dynamic>? result;
  
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () async {
          result = await showDialog<Map<String, dynamic>>(
            context: context,
            builder: (_) => MealComposerDialog(),
          );
        },
        child: Text('Open'),
      ),
    ),
  ));

  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();

  // Add food to cart via search
  await tester.enterText(find.byType(TextField), 'Poulet');
  await tester.pumpAndSettle();
  
  await tester.tap(find.text('Poulet'));
  await tester.pumpAndSettle();

  // Validate meal
  await tester.tap(find.text('Valider Repas'));
  await tester.pumpAndSettle();

  // Verify result structure
  expect(result, isNotNull);
  expect(result!['foods'], isA<String>()); // JSON encoded
  expect(result['tags'], isA<List>());
  expect(result['is_snack'], isA<bool>());
});
```

## Performance Considerations

### Demo Data Generation
**Problem:** Generating 90 days of realistic meals with categorized foods is CPU-intensive.
**Optimizations:**
1. **Food Grouping Algorithm** (database_helper.dart ~line 820):
   ```dart
   // Cache grouped foods instead of filtering on every iteration
   final breakfastFoods = combinedFoods.where((f) => 
     f.category.contains('petit') || 
     f.name.contains('croissant')
   ).toList(); // Only filter once
   ```
2. **Batch Inserts:** Use `Batch` API instead of individual inserts:
   ```dart
   Batch batch = db.batch();
   for (int i = 0; i < events.length; i++) {
     batch.insert('events', events[i]);
   }
   await batch.commit(noResult: true); // Faster than getting IDs
   ```
3. **Expected Time:** ~2-3 seconds for 150+ events (breakfast + lunch + dinner × 30 days)

### OpenFoodFacts API Rate Limiting
**Problem:** Fetching 24 products during enrichment can trigger rate limits.
**Strategy:**
1. **Delay Between Requests** (database_helper.dart ~line 667):
   ```dart
   await Future.delayed(const Duration(milliseconds: 200)); // 5 req/sec max
   ```
2. **Cache First:** Check local DB before API call:
   ```dart
   final existing = await db.query('foods', where: 'barcode = ?', whereArgs: [barcode]);
   if (existing.isNotEmpty) return FoodModel.fromMap(existing.first);
   ```
3. **Batch Optimization:** Group similar products (e.g., all dairy) to reduce total API calls
4. **Expected Time:** ~5-8 seconds for 24 products (200ms × 24 = 4.8s + network latency)

### Meal Grouping Classification
**Complexity:** O(n²) worst case when checking category + tags for each food against all predicates.
**Optimizations:**
1. **Early Exit:** Use `any()` instead of filtering entire list
2. **Case-Insensitive Cache:** Convert to lowercase once:
   ```dart
   final catLower = f.category.toLowerCase();
   final tagsLower = f.tags.map((t) => t.toLowerCase()).toList();
   ```
3. **Limit Checks:** Stop after finding first matching category (breakfast before lunch before dinner)

## Machine Learning Integration

### Architecture Overview
Crohnicles uses **on-device decision tree inference** for symptom risk prediction. Models are trained offline in Python (training/) and exported as JSON for Flutter.

**Why Decision Trees?**
- **Interpretability:** Each prediction provides a human-readable decision path
- **No TFLite Required:** JSON-based tree traversal is lightweight (~10KB per model)
- **Explainability:** Feature importance shows exactly why a meal is flagged as risky

### Training Pipeline (training/train_models.py)

**Workflow:**
1. **Data Extraction:** Queries last 90 days from SQLite (`events` table)
2. **Feature Engineering:** Extracts 60+ features per meal:
   - 11 meal tags (gluten, lactose, gras, etc.)
   - 9 nutrition values (proteins, fats, carbs, fiber, sugars, energy + 3 macro percentages)
   - 11 timing features (hour, day of week, meal type, time since last meal)
   - 10 weather/context features (temperature, pressure, humidity, weather condition)
   - 8 season/time-of-day features (morning, afternoon, evening, night + 4 seasons)
3. **Model Training:** DecisionTreeClassifier with balanced class weights
   - Max depth: 10 (prevents overfitting while maintaining interpretability)
   - Min samples split: 15 (requires sufficient evidence for splits)
   - Min samples leaf: 5 (ensures robust predictions)
4. **Evaluation:** Reports accuracy, precision, recall, F1, confusion matrix
5. **Export:** Serializes tree structure + metadata to JSON (assets/models/)

**Minimum Requirements:**
- 30+ meal events with symptom tracking
- 90-day lookback period
- Symptoms logged 4-8 hours after meals (time window)

**Output Files:**
```
assets/models/
├── pain_predictor.json         # Pain prediction model
├── diarrhea_predictor.json     # Diarrhea prediction model
└── bloating_predictor.json     # Bloating prediction model
```

### On-Device Inference (lib/ml/model_manager.dart)

**Loading Models:**
```dart
final modelManager = ModelManager();
await modelManager.initialize(); // Loads all 3 models from assets

if (!modelManager.isReady) {
  // Fallback to correlation-based heuristics
  // Uses simple tag matching (gras +0.2, gluten +0.15, etc.)
}
```

**Making Predictions:**
```dart
final predictions = await modelManager.predictAllSymptoms(meal, context);

for (final pred in predictions) {
  print('${pred.symptomType}: ${pred.riskEmoji} ${(pred.riskScore * 100).toStringAsFixed(0)}%');
  print('Confidence: ${(pred.confidence * 100).toStringAsFixed(0)}%');
  
  // Top contributing factors
  for (final factor in pred.topFactors) {
    print('  - ${factor.humanReadable} (+${(factor.contribution * 100).toStringAsFixed(0)}%)');
  }
  
  // Human-readable explanation
  print('Explanation: ${pred.explanation}');
}
```

### Prediction Transparency & Justification

**Decision Path Tracing:**
Every prediction includes the exact decision path through the tree:
```dart
final path = model.tree.getDecisionPath(features);
// Example output:
// ["Aliments gras > 0.5", "Heure du repas ≤ 22.0", "Leaf: 78.5% risk"]
```

**Feature Importance:**
Top factors show which features contributed most to the prediction:
```dart
// Example RiskPrediction.topFactors:
[
  TopFactor(featureName: 'tag_gras', contribution: 0.15, 
            humanReadable: 'Aliments riches en graisses'),
  TopFactor(featureName: 'tag_gluten', contribution: 0.12,
            humanReadable: 'Présence de gluten'),
  TopFactor(featureName: 'is_late_night', contribution: 0.08,
            humanReadable: 'Repas tardif (après 22h)'),
]
```

**Risk Score Interpretation:**
- **0.0-0.3 (Low 🟢):** "Risque faible de [symptom]. Ce repas présente peu de facteurs déclencheurs habituels."
- **0.3-0.7 (Medium 🟡):** "Risque modéré de [symptom]. Surveillez l'apparition de symptômes dans les 4-8 heures."
- **0.7-1.0 (High 🔴):** "Risque élevé de [symptom]. Ce repas contient plusieurs facteurs déclencheurs identifiés."

**Confidence Metrics:**
- Derived from model F1 score during training
- Typical range: 0.6-0.9 (60-90% confidence)
- Lower confidence → suggest collecting more data

**Fallback Heuristics (No Models Loaded):**
Uses correlation-based scoring when models unavailable:
```dart
double riskScore = 0.3; // Base risk
if (tags.contains('gras')) riskScore += 0.2;
if (tags.contains('gluten')) riskScore += 0.15;
if (tags.contains('lactose')) riskScore += 0.15;
// Clamped to [0.0, 1.0]
```
Confidence set to 0.6 for correlation-based predictions.

### Feature Engineering Details (lib/ml/feature_extractor.dart)

**60+ Features Extracted Per Meal:**

1. **Meal Tags (11 binary features):** féculent, protéine, légume, produit_laitier, fruit, épices, gras, sucre, fermenté, gluten, alcool
2. **Nutrition (9 continuous features):** protein_g, fat_g, carb_g, fiber_g, sugar_g, energy_kcal, protein_pct, fat_pct, carb_pct
3. **Processing (2 features):** nova_group (1-4 scale), is_processed (binary)
4. **Timing (11 features):** hour_of_day, day_of_week, is_weekend, is_breakfast, is_lunch, is_dinner, is_snack, is_late_night, minutes_since_last_meal, hours_since_last_meal, meals_today_count
5. **Weather/Context (10 features):** temperature_celsius, pressure_hpa, pressure_change_6h, humidity, is_high_humidity, is_pressure_dropping, weather_sunny, weather_rainy, weather_cloudy, weather_stormy
6. **Time/Season (8 features):** time_morning, time_afternoon, time_evening, time_night, season_spring, season_summer, season_fall, season_winter

**Critical Pattern:**
Features must **exactly match** between training (Python) and inference (Dart). Any mismatch breaks predictions.
- Python extracts features in `train_models.py::_extract_features()`
- Dart mirrors this in `feature_extractor.dart::extractMealFeatures()`
- **Test:** Compare feature names and order between both implementations

### Retraining Workflow

**When to Retrain:**
- New symptom events logged (daily/weekly automatic retraining planned)
- Model performance degrades (F1 < 0.6)
- User reports incorrect predictions

**Manual Retraining:**
```bash
cd training/
python train_models.py
# Models exported to ../assets/models/
# Restart app to reload models
```

**Automated Retraining (Planned):**
- WorkManager integration (training_service.dart)
- Nightly retraining at 3 AM
- Stores training history in `training_history` table
- Compares new vs. old F1 scores before swapping models

### Model Performance Monitoring

**Accessing Metrics:**
```dart
final metrics = modelManager.getModelMetrics();
print('Pain model F1: ${metrics['pain']!['f1']}');
print('Diarrhea model accuracy: ${metrics['diarrhea']!['accuracy']}');
```

**Typical Performance (with 90+ days of data):**
- Accuracy: 75-85%
- Precision: 70-80% (few false positives)
- Recall: 65-75% (catches most symptoms)
- F1 Score: 70-78% (balanced)

**Degradation Indicators:**
- F1 < 0.6: Model needs retraining
- Accuracy < 70%: Insufficient training data
- Precision < 60%: Too many false alarms (reduce sensitivity)