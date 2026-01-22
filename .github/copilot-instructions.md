# Crohnicles Project Instructions

## Project Overview
"Crohnicles" is a Flutter application for tracking health events (IBD/Crohn's) with a "Local First" architecture using SQLite.
**Stack:** Flutter (Material 3), Dart, sqflite (Storage), l_chart (Viz), intl.

## Architecture & Core Components

### Data Layer (lib/database_helper.dart)
- **Singleton Pattern:** Access via DatabaseHelper().
- **Tables:**
  - events: Central log. Uses meta_data (JSON) to store complex structures (e.g. list of food items).
  - oods: Local database for autocomplete. Seeded with 50+ common items.
- **Dates:** Stored as **ISO8601 Strings** (YYYY-MM-DDTHH:MM:SS).
- **Queries:** Contains raw SQL for analytics (getPainEvolution, getStoolFrequency).

### Models
- **lib/event_model.dart**: Immutable class representing a unified timeline event.
  - EventType: meal, symptom, stool, daily_checkup.
  - Properties: 	ags (List<String>), meta_data (JSON String), severity (0-10).
- **lib/food_model.dart**: Represents an ingredient/food item with category and tags.

### UI Structure & Navigation
- **Entry Point (lib/main.dart):** Holds the main TimelinePage and global _addEvent logic.
- **Composer Pattern:** Complex inputs are decoupled into "Composer" dialogs:
  - **Meal:** lib/meal_composer_dialog.dart (Cart system, Autocomplete, Category Filters).
  - **Symptom:** lib/symptom_dialog.dart (Hierarchical drill-down selection).
  - **Stool:** lib/stool_entry_dialog.dart (Bristol scale visual selector).
- **Analysis:** lib/insights_page.dart uses l_chart to visualize SQL aggregation results.

## Key Developer Workflows

### 1. Adding a New Event Type
1. Define type in EventType enum (event_model.dart).
2. Create a specialized Dialog Widget (return Map<String, dynamic>).
3. Add launch button in _showAddMenu (main.dart).
4. Handle the result in the dialog' callback to call _addEvent.
5. Add a specific Card widget (_buildXCard) in TimelinePage.

### 2. Modifying Database Schema
1. Increment ersion in _initDatabase.
2. Add migration logic in _onUpgrade (e.g., ALTER TABLE...).
3. **Never** rename columns; only add new ones or create new tables.

### 3. Working with Charts (insights_page.dart)
- **Data Source:** Always fetch specific aggregations from DatabaseHelper (avoid processing all events in Dart if possible).
- **Formatting:** Convert SQL dates to relative X-values (e.g., "Day 0" to "Day 30").
- **Styling:** Use LineChart for trends (Pain) and BarChart for counts (Stools).

## Conventions & Patterns

- **Dialogs:**
  - Return **Raw Data** (Map or List) via Navigator.pop.
  - **Do Not** perform DB writes inside the dialog (unless it's self-contained data like "New Food Creation").
  - Use SizedBox(width: double.maxFinite) in AlertDialog content to prevent layout issues.
- **Images:**
  - Use image_picker.
  - **Desktop Fix:** Explicitly handle Windows/Linux file paths (copy to AppDocumentsDirectory).
- **Icons:**
  - Prefer **Material Icons** (Icons.local_drink) over Emojis for better cross-platform rendering (especially Windows).
- **Tagging:**
  - Auto-tagging logic (e.g., "Pâtes" -> adds "Féculent" tag) happens at the **Entry** level (MealComposerDialog).

## Common Tasks Reference
- **Seed Data:** DatabaseHelper._seedFoods handles initial population.
- **Event Search:** EventSearchDelegate (lib/event_search_delegate.dart) implements native search.
- **Platform Init:** sqflite FFI initialization for Web/Desktop is in main().
