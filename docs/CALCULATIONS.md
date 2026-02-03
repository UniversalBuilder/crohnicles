# Documentation des Calculs & Formules - Crohnicles

**Version:** 1.1  
**Dernière mise à jour:** 3 février 2026

Ce document centralise toutes les formules statistiques, seuils algorithmiques et règles de transparence utilisées dans Crohnicles. Il garantit la reproductibilité et la compréhension des analyses présentées aux utilisateurs.

---

## 📊 I. ANALYSES STATISTIQUES DE BASE

### 1.1 Probabilité Conditionnelle de Symptômes

**Formule:**
```
P(Symptom | Feature) = count_with_symptom / count_total
```

**Variables:**
- `count_with_symptom`: Nombre de jours où Feature ET Symptom sont présents
- `count_total`: Nombre total de jours où Feature est présent

**Exemple:**
```
12 jours froids avec douleurs articulaires / 15 jours froids total = 80%
```

**Implémentation:** `lib/services/statistical_engine.dart` (ligne ~450)

---

### 1.2 Score de Confiance (Fiabilité)

**Formule:**
```
Confidence = min(sample_size / 10.0, 1.0)
```

**Seuils:**
- `sample_size < 5`: Confiance insuffisante (🟡 Badge "Insuffisant")
- `5 ≤ sample_size < 10`: Confiance indicative (🟠 Badge "Indicatif")
- `sample_size ≥ 10`: Confiance fiable (🟢 Badge "Fiable")

**Exemple:**
```
8 jours de données → Confidence = min(8/10, 1.0) = 0.8 (80%)
→ Badge "Indicatif"
```

**Implémentation:** `lib/services/statistical_engine.dart` (méthode `_calculateConfidence()`)

---

### 1.3 Score Combiné (Risque)

**Formule:**
```
Risk Score = P(Symptom|Feature) × Confidence × 100
```

**Classification:**
- **Élevé** (🔴): Score ≥ 60%
- **Moyen** (🟠): 30% ≤ Score < 60%
- **Faible** (🟢): Score < 30%

**Exemple:**
```
Probabilité = 75%, Confiance = 0.8
→ Score = 0.75 × 0.8 × 100 = 60% (Risque Élevé)
```

**Implémentation:** `lib/ml/model_manager.dart` (méthode `predictRisk()`)

---

## 🌦️ II. CORRÉLATIONS MÉTÉOROLOGIQUES

### 2.1 Seuils de Température

**Définitions:**
```
Température Froide:  T < 12°C
Température Normale: 12°C ≤ T ≤ 28°C
Température Chaude:  T > 28°C
```

**Rationale:** Seuils basés sur études dermatologiques (impact froid sur circulation) et confort thermique (ISO 7730).

**Implémentation:** `lib/services/context_service.dart` (constantes `COLD_THRESHOLD`, `HOT_THRESHOLD`)

---

### 2.2 Seuils d'Humidité

**Définitions:**
```
Humidité Basse:    H < 30%
Humidité Normale:  30% ≤ H ≤ 70%
Humidité Élevée:   H > 70%
```

**Rationale:** Normes OMS pour confort respiratoire et prévention moisissures.

**Implémentation:** `lib/services/context_service.dart` (constantes `LOW_HUMIDITY`, `HIGH_HUMIDITY`)

---

### 2.3 Catégories de Pression Atmosphérique

**Définitions:**
```
Basse Pression:    P < 1000 hPa
Pression Normale:  1000 hPa ≤ P ≤ 1020 hPa
Haute Pression:    P > 1020 hPa
```

**Rationale:** Variations significatives pour baromètre médical (migraines, arthrose).

**Implémentation:** `lib/services/context_service.dart` (constantes `LOW_PRESSURE`, `HIGH_PRESSURE`)

---

### 2.4 Formule de Corrélation Météo

**Calcul:**
```dart
// Pour chaque condition météo (ex: "Jours froids")
int symptomDays = 0;
int totalDays = 0;

for (event in dailyCheckups) {
  if (temperature < 12) { // Condition = vraie
    totalDays++;
    if (event.metaData['symptoms'].contains('Articulaires')) {
      symptomDays++;
    }
  }
}

double frequency = totalDays > 0 ? (symptomDays / totalDays) : 0.0;
```

**Affichage utilisateur:**
```
"12 jours froids sur 15 avaient des douleurs articulaires (80%)"
"Votre taux habituel de douleurs articulaires : 35%"
```

**Implémentation:** `lib/insights_page.dart` (méthode `_buildWeatherStackedBarChart()`)

---

## 🧠 III. MACHINE LEARNING & PRÉDICTIONS

### 3.1 Extraction de Features (60+ Variables)

**Fichier source:** `lib/ml/feature_extractor.dart`

**Catégories:**
1. **Aliments (15 features)** → Categories: Gluten, Lactose, FODMAP, etc.
2. **Tags (8 features)** → Sucre ajouté, Gras saturés, Additifs, etc.
3. **Nutritionnels (10 features)** → Protéines, Glucides, Lipides, Énergie, etc.
4. **Temporels (5 features)** → Heure, Jour semaine, Weekend, etc.
5. **Contexte (8 features)** → Stress, Sommeil, Activité physique, etc.
6. **Météo (6 features)** → Température, Humidité, Pression, Précipitations, etc.
7. **Historiques (8 features)** → Symptômes 24h/48h/72h avant, etc.

**Exemple Feature Vector:**
```dart
{
  'has_gluten': 1.0,         // Binaire
  'has_lactose': 0.0,
  'hour_of_day': 12.5,       // 0-23 normalisé
  'proteins_100g': 0.15,     // Normalisé
  'temperature': 0.45,       // (T - min) / (max - min)
  'stress_level': 3.0,       // 0-5
  'symptoms_last_24h': 2.0   // Count
}
```

**Validation:** Les noms et l'ordre DOIVENT correspondre au script Python `training/train_models.py`.

---

### 3.2 Fenêtre Temporelle de Causalité

**Paramètre:**
```
WINDOW_HOURS = 8 (heures)
```

**Logique:**
```
Un repas à 13h peut déclencher un symptôme jusqu'à 21h.
```

**Rationale:** Temps de transit intestinal moyen (4-8h) + marge sécurité.

**Implémentation:** `lib/services/statistical_engine.dart` (constante `WINDOW_HOURS`)

---

### 3.3 Seuils de Dataset pour Entraînement

**Minimums requis:**
```
MIN_MEALS = 30      // Minimum d'événements repas
MIN_SYMPTOMS = 20   // Minimum d'événements symptômes
```

**Validation:**
```dart
if (meals.length < MIN_MEALS || symptoms.length < MIN_SYMPTOMS) {
  throw InsufficientDataException();
}
```

**Implémentation:** `lib/services/statistical_engine.dart` (méthode `train()`)

---

### 3.4 Prédiction de Risque (ML Model)

**Architecture:** Decision Tree (max_depth=5, min_samples_split=5)

**Output:**
```dart
class RiskPrediction {
  double painRisk;        // 0.0-1.0
  double bloatingRisk;    // 0.0-1.0
  double diarrheaRisk;    // 0.0-1.0
  double confidence;      // 0.0-1.0
  int dataPoints;         // Sample size
}
```

**Interprétation:**
```
painRisk = 0.75 (75%)
confidence = 0.9 (90%)
dataPoints = 45

→ "Ce repas a 75% de probabilité de déclencher des douleurs 
   (basé sur 45 repas similaires, confiance élevée)"
```

**Implémentation:** `lib/ml/model_manager.dart` (méthode `predictRisk()`)

---

## 🎯 IV. RÈGLE DE TRANSPARENCE ABSOLUE

### 4.1 Les 5 Informations Obligatoires

**Pour CHAQUE statistique affichée, fournir:**

1. **Corrélation brute (Contexte):**
   ```
   "12 jours froids sur 15 avaient des douleurs articulaires (80%)"
   ```

2. **Baseline comparative (Référence):**
   ```
   "Votre taux habituel de douleurs articulaires : 35%"
   ```

3. **Signification claire (Badge visuel):**
   ```
   🔴 "Forte corrélation" (>60%)
   🟠 "Modérée" (30-60%)
   🟢 "Faible" (<30%)
   ⚪ "Aucune" (baseline ±5%)
   ```

4. **Fiabilité / Taille échantillon (Confiance):**
   ```
   🟢 "Fiable" (≥10 jours)
   🟠 "Indicatif" (5-9 jours)
   🟡 "Insuffisant" (<5 jours)
   ```

5. **Type de symptôme spécifique (Granularité):**
   ```
   ❌ "Tous symptômes" (trop vague)
   ✅ "Douleurs articulaires"
   ✅ "Fatigue intense"
   ✅ "Symptômes digestifs"
   ```

### 4.2 Terminologie Précise

**À UTILISER:**
- "Probabilité" → Indique fréquence observée
- "Fréquence" → Nombre d'occurrences
- "Taux" → Pourcentage calculé

**À ÉVITER:**
- "Corrélation" seul → Ambigu (force? direction?)
- "Risque" sans contexte → Angoissant
- "Impact" sans quantification → Subjectif

### 4.3 Graphiques Obligatoires

**Éléments requis:**
1. **Légende** → Expliquer couleurs/barres
2. **Axes nommés** → Unités claires (%, jours, score)
3. **Tooltip au hover** → Détails au survol
4. **Annotation baseline** → Ligne pointillée pour référence
5. **Source données** → "Basé sur vos 90 derniers jours"

**Exemple (fl_chart):**
```dart
BarChart(
  BarChartData(
    titlesData: FlTitlesData(
      leftTitles: AxisTitles(
        axisNameWidget: Text('Fréquence de symptômes (%)'),
      ),
      bottomTitles: AxisTitles(
        axisNameWidget: Text('Conditions météorologiques'),
      ),
    ),
    barTouchData: BarTouchData(
      touchTooltipData: BarTouchTooltipData(
        getTooltipItem: (group, groupIndex, rod, rodIndex) {
          return BarTooltipItem(
            '${rod.toY.toStringAsFixed(1)}%\n',
            TextStyle(fontWeight: FontWeight.bold),
            children: [
              TextSpan(
                text: 'Baseline: ${baseline}%',
                style: TextStyle(fontSize: 12),
              ),
            ],
          );
        },
      ),
    ),
  ),
)
```

**Implémentation:** `lib/insights_page.dart` (tous les graphiques fl_chart)

---

## 📈 V. FLUX DE TRAITEMENT DES DONNÉES

### 5.1 Pipeline d'Analyse

```mermaid
DatabaseHelper (SQLite)
    ↓ Query événements
StatisticalEngine
    ↓ Calcul P(Symptom|Feature)
    ↓ Calcul Confidence
    ↓ Extraction features
ModelManager
    ↓ Chargement modèle .tflite ou DecisionTree
    ↓ Prédiction RiskPrediction
UI Layer (InsightsPage, RiskAssessmentCard)
    ↓ Affichage avec 5 infos obligatoires
    ↓ Graphiques fl_chart avec tooltips
Utilisateur
```

### 5.2 Ordre de Priorité (Fallback)

1. **TFLite Model** (si fichier existe et valide)
2. **DecisionTree Model** (si entraîné avec ≥30 repas)
3. **Statistical Engine** (calculs probabilistes de base)
4. **Fallback Message** ("Données insuffisantes, continuez à enregistrer")

**Implémentation:** `lib/ml/model_manager.dart` (méthode `predictRisk()`)

---

## 🧪 VI. VALIDATION & TESTS

### 6.1 Tests de Calculs

**Fichier:** `test/correlations_test.dart`

**Scénarios couverts:**
- P(Symptom|Feature) avec datasets connus
- Score de confiance (3, 7, 12 échantillons)
- Classification risque (Faible/Moyen/Élevé)
- Seuils météo (edge cases: 11.9°C, 12.0°C, 28.1°C)

### 6.2 Accuracy Targets

**Machine Learning:**
- **Train Accuracy:** ≥75% (tolérance overfitting léger)
- **Test Accuracy:** ≥70% (20% holdout dataset)
- **Latence:** <100ms sur Pixel 6 / iPhone 13
- **Memory:** <50MB pendant inférence

**Statistical Engine:**
- **Precision:** ≥65% (détection vrais positifs)
- **Recall:** ≥60% (couverture symptômes)
- **F1-Score:** ≥62% (équilibre Precision/Recall)

### 6.3 Edge Cases Documentés

1. **Dataset trop petit:** Afficher message "Continuez à enregistrer (X/30 repas)"
2. **Features manquantes:** Utiliser valeurs par défaut (0.0 pour binaires, médiane pour continues)
3. **Modèle corrompu:** Supprimer .tflite, retour à StatisticalEngine, notification utilisateur
4. **Corrélation 100%:** Toujours afficher taille échantillon ("3/3 jours, échantillon insuffisant")
5. **Baseline identique:** Afficher "Aucune corrélation détectable" plutôt que 0%

---

## 📚 VII. RÉFÉRENCES & SOURCES

### 7.1 Standards Médicaux
- **Temps de transit:** Madsen et al. (1992), Gut, 33(9):1203-1206
- **Seuils température:** ISO 7730:2005 (Ergonomie environnements thermiques)
- **FODMAP:** Monash University FODMAP Diet (2021)

### 7.2 Statistiques
- **Seuil confiance (n=10):** Central Limit Theorem (n≥30 idéal, 10 minimum pratique)
- **Classification risque:** Percentiles basés sur dataset pilote (50 utilisateurs, 2024)

### 7.3 Machine Learning
- **Decision Tree:** Scikit-learn Documentation (max_depth selection)
- **Feature Engineering:** "Feature Engineering for Machine Learning" (Zheng & Casari, 2018)

---

## 🔄 VIII. HISTORIQUE DES CHANGEMENTS

### v1.1 (3 février 2026)
- Ajout formule Score Combiné (Risque)
- Documentation complète des 5 infos obligatoires
- Ajout seuils météo (température, humidité, pression)
- Définition pipeline d'analyse (diagramme Mermaid)

### v1.0 (30 janvier 2026)
- Création document initial
- Documentation P(Symptom|Feature)
- Seuils de confiance
- Fenêtre temporelle (8h)

---

**Note finale:** Ce document est la source de vérité pour tous les calculs de Crohnicles. En cas de divergence entre le code et ce document, le document fait foi (après validation médicale si nécessaire). Toute modification d'algorithme DOIT être reflétée ici avec justification.
