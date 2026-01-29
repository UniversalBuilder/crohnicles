# Architecture State & Dependency Graph
*Last Updated: [Date du jour]*

## 1. Structure de la Base de Données (Source de Vérité)
### Table `events`
- **id**: INTEGER PRIMARY KEY
- **date**: TEXT (ISO8601)
- **type**: TEXT (meal, symptom, stool, daily_checkup)
- **severity**: INTEGER (0-10)
- **meta_data**: TEXT (JSON)
  - *Meal:* `{'foods': [...], 'is_snack': bool, 'tags': [...]}`
  - *Symptom:* `{'locations': [...], 'triggers': [...]}`

### Table `foods` & `products_cache`
- Servent à l'autocomplétion et à l'enrichissement OFF.

## 2. Dépendances Critiques (Si tu touches A, vérifie B)
| Si tu modifies... | Tu DOIS vérifier... |
|-------------------|---------------------|
| `EventModel` | `DatabaseHelper` (ToMap/FromMap), `feature_extractor.dart` (ML), `TimelinePage` (Affichage) |
| `MealComposerDialog` | Le format JSON dans `meta_data` (ne jamais casser la structure objet) |
| `OFFService` | Le Rate Limiter (ne pas DDOS l'API) et le Cache (TTL) |
| `feature_extractor.dart` | `train_models.py` (Python) - Les features doivent être identiques |

## 3. État Actuel des Fonctionnalités
- **Saisie Repas :** Fonctionnelle (Scanner + Recherche + Création).
- **ML :** Modèles chargés depuis assets/models/. Fallback heuristique si absent.
- **Charts :** Corrélation Douleur/Repas sur 90 jours.

## 4. Log des Dernières Modifications Majeures
- [Date] Initialisation du fichier d'architecture.
- [29/01/2026] Refonte Module Repas:
  - **Data :** Migration v9, Ajout `generic_foods.dart` pour source vérité locale.
  - **CRUD :** Fix serialization/deserialization JSON dans `MealComposerDialog` & `MainPage`.
  - **Search :** Priorité aux aliments génériques locaux vs OpenFoodFacts.
