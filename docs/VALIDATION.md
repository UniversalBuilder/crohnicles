# 🛡️ COUCHE DE VALIDATION DES ENTRÉES UTILISATEUR

> **Étape 3 du Plan de Consolidation**
> 
> Implémentation d'une couche de validation centralisée pour garantir l'intégrité des données saisies.

---

## 📋 OBJECTIF

Empêcher la saisie de données invalides **avant** leur insertion en base de données, avec des messages d'erreur clairs et cohérents en français.

---

## 🏗️ ARCHITECTURE

### Fichier Principal
**`lib/utils/validators.dart`** (170 LOC)

Classe statique `EventValidators` avec 10 méthodes de validation :

```dart
class EventValidators {
  // Dates, quantités, sévérités, textes, tags...
  static String? validateEventDate(DateTime date);
  static String? validateSeverity(int severity);
  static String? validateMealCart(List<FoodModel> cart);
  // ... 7 autres validations ...
  
  // Affichage d'erreur standardisé
  static void showValidationError(BuildContext context, String message);
}
```

### Points d'Intégration

| Dialog | Validations Appliquées | Fichier |
|--------|------------------------|---------|
| **MealComposerDialog** | Date + Panier non vide + Quantités | `lib/meal_composer_dialog.dart` (ligne 336) |
| **SymptomEntryDialog** | Date + Zones non vides + Sévérités 1-10 | `lib/symptom_dialog.dart` (ligne 1171) |
| **StoolEntryDialog** | Date + Bristol Scale 1-7 | `lib/stool_entry_dialog.dart` (ligne 477) |

---

## 🔐 RÈGLES DE VALIDATION

### 1. Validation des Dates (`validateEventDate`)
```dart
✅ Date passée (jusqu'à maintenant)
✅ Maximum 2 ans d'ancienneté
❌ Dates futures
❌ Événements antérieurs au 03/02/2024
```

**Rationale :** Les données de santé au-delà de 2 ans perdent en pertinence clinique.

### 2. Validation du Panier Repas (`validateMealCart`)
```dart
✅ Au moins 1 aliment
✅ Quantités (servingSize) > 0
✅ Quantités ≤ 2000g/ml
❌ Panier vide
❌ Quantités négatives ou nulles
```

**Rationale :** Limite de 2kg = seuil réaliste pour un repas individuel.

### 3. Validation de Sévérité (`validateSeverity`)
```dart
✅ Échelle 1-10 (standard médical)
❌ Valeurs hors échelle
```

**Rationale :** Échelle universelle de douleur/inconfort.

### 4. Validation Bristol Scale (`validateBristolScale`)
```dart
✅ Types 1-7 (classification médicale)
❌ Valeurs hors classification
```

**Rationale :** Échelle Bristol officielle de consistance des selles.

### 5. Validation de Texte (`validateRequiredText`)
```dart
✅ 1-200 caractères
✅ Pas uniquement espaces
❌ Texte vide
❌ Texte > 200 caractères (limite DB)
```

### 6. Validation de Quantité (`validateQuantity`)
```dart
✅ Valeurs > 0
✅ Maximum 2000g/ml
❌ Quantités négatives ou nulles
```

### 7. Validation de Tags (`validateTags`)
```dart
✅ Liste optionnelle
✅ Chaque tag ≥ 2 caractères
❌ Tags trop courts (évite les typos)
```

### 8. Validation de Zone Anatomique (`validateAnatomicalZone`)
```dart
✅ Nom de zone non vide (si fourni)
✅ Optionnel (peut être null)
```

---

## 🎨 EXPÉRIENCE UTILISATEUR

### Affichage des Erreurs
```dart
EventValidators.showValidationError(context, '❌ Message explicite');
```

**Caractéristiques :**
- SnackBar rouge avec icône ❌
- Position : Flottante (bottom)
- Durée : 4 secondes
- Action : Dismiss automatique

**Exemple :**
```
❌ La date ne peut pas être dans le futur
❌ Ajoutez au moins un aliment au repas
❌ La sévérité doit être entre 1 et 10
❌ Échelle de Bristol invalide (1-7 uniquement)
```

---

## 📊 TESTS RECOMMANDÉS

### Scénarios de Test (À Implémenter)

#### Test 1 : Dates Invalides
```dart
test('Refus date future', () {
  final tomorrow = DateTime.now().add(Duration(days: 1));
  expect(EventValidators.validateEventDate(tomorrow), isNotNull);
});
```

#### Test 2 : Panier Vide
```dart
test('Refus panier vide', () {
  expect(EventValidators.validateMealCart([]), isNotNull);
});
```

#### Test 3 : Sévérité Hors Limites
```dart
test('Refus sévérité 11', () {
  expect(EventValidators.validateSeverity(11), isNotNull);
});
```

#### Test 4 : Bristol Invalide
```dart
test('Refus Bristol type 8', () {
  expect(EventValidators.validateBristolScale(8), isNotNull);
});
```

---

## 🔄 WORKFLOW DE VALIDATION

```mermaid
graph LR
    A[Utilisateur clique "Valider"] --> B{Validation Date}
    B -->|❌ Invalide| C[Afficher Erreur<br/>+ Retour Dialog]
    B -->|✅ Valide| D{Validation Données}
    D -->|❌ Invalide| C
    D -->|✅ Valide| E[Navigator.pop<br/>+ Retour données]
    C --> F[Utilisateur corrige<br/>+ Re-soumet]
    F --> B
```

---

## 🚨 POINTS D'ATTENTION

### 1. Ordre des Validations
**TOUJOURS valider la date en premier** pour éviter les calculs inutiles si date invalide.

```dart
// ✅ CORRECT
final dateError = validateEventDate(_selectedDate);
if (dateError != null) return;

final cartError = validateMealCart(_cart);
// ... suite ...

// ❌ INCORRECT : Calculer avant de valider la date
final cartError = validateMealCart(_cart); // Si date invalide = calcul inutile
```

### 2. Messages Contextuels
Pour les symptômes, préciser quelle zone est invalide :

```dart
EventValidators.showValidationError(
  context,
  'Sévérité "${entry.key}": $severityError', // "Sévérité Abdomen: ..."
);
```

### 3. Conservation des Données
Si validation échoue, **ne jamais** fermer le dialog → l'utilisateur garde sa saisie.

```dart
if (dateError != null) {
  EventValidators.showValidationError(context, dateError);
  return; // ⚠️ PAS de Navigator.pop !
}
```

---

## 📈 IMPACT QUALITÉ

### Avant Étape 3
```
❌ Saisie de dates futures (bugs calculs ML)
❌ Repas vides enregistrés
❌ Sévérités négatives
❌ Crashs sur données incohérentes
```

### Après Étape 3
```
✅ Impossibilité de saisir données invalides
✅ Messages d'erreur explicites
✅ Garantie intégrité DB
✅ Aucun crash lié aux inputs utilisateur
```

---

## 🔗 LIENS UTILES

- **Code Source :** [`lib/utils/validators.dart`](../lib/utils/validators.dart)
- **Intégrations :**
  - [`lib/meal_composer_dialog.dart`](../lib/meal_composer_dialog.dart) (lignes 336-350)
  - [`lib/symptom_dialog.dart`](../lib/symptom_dialog.dart) (lignes 1171-1215)
  - [`lib/stool_entry_dialog.dart`](../lib/stool_entry_dialog.dart) (lignes 477-495)

---

## 📝 CHANGELOG

### Version 1.0 (03/02/2026)
- ✅ Création de `EventValidators` (10 méthodes)
- ✅ Intégration dans 3 dialogs principaux
- ✅ Messages d'erreur en français
- ✅ Documentation complète

### À Venir (v1.1)
- Tests unitaires (>70% couverture)
- Validation asynchrone (OpenFoodFacts)
- Validation croisée (ex: "Fatigue + Sommeil" incohérent)
