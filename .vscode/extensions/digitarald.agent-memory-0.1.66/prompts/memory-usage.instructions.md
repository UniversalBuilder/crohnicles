# Memory - Crohnicles

## Project Status
**Current Phase:** Phase 4 (Intelligence Locale) - Refactoring & Granularity
**Goal:** Refine data input for better analysis.

## Progress
- [x] Phase 1-3 complete.
- [x] Phase 4 (Charts & Analysis) mvp complete.
- [x] **Refactoring Data Input (Task 1 & 2):**
    - [x] **Symptom Tree:** Created `lib/symptom_dialog.dart` with hierarchical navigation.
    - [x] **Meal Composer (Major Refactor):**
        - [x] **Database:** Added `foods` table with Seeding (~50 items).
        - [x] **UI:** Created `MealComposerDialog` with Cart system (Multi-item meals) & Autocomplete.
        - [x] **Feature:** "Create Food" flow for unknown items.
        - [x] **Data:** Events now store full JSON of meal items in `meta_data`.
- [x] **Insights Dashboard (Sprint 4):**
    - [x] **SQL:** Implemented aggregate queries (`getPainEvolution`, `getStoolFrequency`).
    - [x] **Visu:** Integrated `fl_chart` for Pain (Line) and Stool (Bar).
    - [x] **Logic:** Pattern detection improved using tags/ingredients from new meal composer.

## Technical Decisions
- **Granularity:** Structured hierarchy for Symptoms.
- **Meal Data:** Moving from single text field to List of `FoodModel` (Cart system).
- **Separation of Concerns:** Componentized `SymptomEntryDialog` and `MealComposerDialog`.
- **Database:** SQLite `foods` table replaces static lists; Raw queries used for time-series aggregation.

## Next Steps
- Validate the new "Meal Composer" and "Insights" UI.
- Add "Statistics" or "Trends" (part of Phase 2 originally, but fits Phase 3).
- Export data (PDF/CSV).
