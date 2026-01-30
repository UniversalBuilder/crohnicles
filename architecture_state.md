# Journal d'Architecture

## 2026-01-30 - Refonte UI & Maintenance
### Changements
1.  **Gestion des Logs & Paramètres** :
    - Création de `SettingsPage` pour centraliser les outils dev et maintenance.
    - Création de `LogsPage` et `LogService` pour un debug sur appareil.
    - Nettoyage de `main.dart` (suppression du menu dev inline).

2.  **ML & Insights** :
    - Ajout d'un bouton "Dernière analyse" dans `InsightsPage`.
    - Correction de l'overflow dans `ModelStatusPage` via `Expanded` et `maxLines`.
    - Intégration de la page `MethodologyPage`.

3.  **Background Service** :
    - Fix critique sur l'accès DB (path + `onCreate`).
    - Ajout de logs explicites via `LogService`.
    - Hotfix `main.dart`: Restauration des imports manquants et définition de `_deleteEvent`.

## 2026-01-30 (Suite) - Analyse Interactive des Déclencheurs

### Changements
1.  **Nouvelle Fonctionnalité : Drill-Down sur PieChart**
    - Ajout de `pieTouchData` sur le diagramme de localisation des douleurs
    - Click sur une section → analyse approfondie des déclencheurs
    - Interface interactive pour explorer les corrélations

2.  **Algorithme de Scoring Robuste**
    - Calcul de P(Symptom|Trigger) avec seuils de fiabilité
    - Score = Probabilité × Confiance (basée sur taille d'échantillon)
    - Seuil minimum : 3 symptômes pour analyse, 2 occurrences par trigger
    - Lissage progressif de la confiance (max à 10+ échantillons)

3.  **UI Bottom Sheet avec Export**
    - Affichage structuré : Aliments, Tags, Météo
    - Indicateur de risque visuel (Élevé/Moyen/Faible)
    - Bouton export → copie rapport texte vers clipboard
    - Gestion "données insuffisantes" (<3 symptômes)
    - DraggableScrollableSheet pour meilleure UX mobile

4.  **Nouvelles Méthodes DB**
    - `getSymptomsByZone(zoneName)` : filtre symptômes par zone avec LIKE
    - `getMealsInRange(start, end)` : extraction repas pour fenêtre temporelle
    - Support de l'analyse de corrélation météo via context_data

5.  **Classes de Modélisation**
    - `ZoneTriggerAnalysis` : encapsulation résultats d'analyse
    - `TriggerScore` : scoring individuel avec probability/confidence

### Dette Technique
- L'extraction météo depuis context_data n'est pas testée (peu d'events avec contexte).
- Pas de cache pour les analyses répétées (recalcul à chaque click).
- La catégorisation météo est simpliste (basée uniquement temp + keywords condition).
- Les tests unitaires sont minimaux (`ModelManager` only).
- L'injection de dépendances pour `LogService` est un Singleton simple (suffisant pour l'instant).

## 2026-01-30 (Hotfix) - Correction getContextForEvent

### Changements
1.  **Fix Critique dans database_helper.dart**
    - Ajout de la méthode `getContextForEvent(int eventId)` manquante
    - Extraction et parsing JSON de la colonne `context_data`
    - Gestion des erreurs de parsing avec fallback null
    - Résolution de 3 erreurs d'analyse statique dans insights_page.dart

2.  **Nettoyage Warnings**
    - Suppression de l'import inutilisé `package:flutter/foundation.dart` dans insights_page.dart
    - Suppression de la méthode obsolète `_analyzePatterns_old` (57 lignes)
    - Conservation de `weatherWithSymptomCounts` (nécessaire pour analyse météo)

3.  **Validation**
    - flutter analyze : 0 erreurs, 9 warnings, 165 infos (all non-critical)
    - App démarre et fonctionne correctement sur Windows
    - Feature d'analyse des déclencheurs est maintenant 100% fonctionnelle

## 2026-01-30 (Consolidation) - Refonte Complète: Stats vs ML

### Motivation
Clarifier la distinction entre modèles statistiques et prédictions temps réel, corriger l'historique d'entraînement vide, limiter la surcharge d'information, et réduire la dette technique en supprimant le code Python/Desktop mort.

### Changements Majeurs

#### 1. Schéma Base de Données (v10 → v11)
- **training_history simplifié**: Suppression colonnes ML (`f1_score`, `precision`, `recall`, `model_name`, `feature_importances`)
- **Nouveau schéma**: `id`, `trained_at`, `meal_count`, `symptom_count`, `correlation_count`, `notes`
- **Migration automatique**: DROP + CREATE pour utilisateurs existants (aucun utilisateur en production)
- **Nouvelle méthode**: `saveTrainingHistory()` pour persister les résultats

#### 2. Statistical Engine Amélioré
- **Calcul de confiance basé sur échantillon**: `confidence = min(N/10.0, 1.0)` au lieu de fixed 0.8
- **Nouveau format JSON v2.0**: Chaque corrélation stocke `{probability, confidence, sample_size}`
- **Retour correlation_count**: `TrainingResult` inclut maintenant le nombre total de corrélations trouvées
- **Persistence automatique**: `training_service.dart` sauvegarde l'historique après chaque training

#### 3. Model Manager: 2 Niveaux Uniquement
- **SUPPRIMÉ**: Code Python/Desktop training (Process.run, train_models.py, assets/models/)
- **SUPPRIMÉ**: Heuristiques fallback hardcodées (_fallbackPredictions avec 100+ lignes de if/else)
- **NOUVEAU**: Propriété publique `isUsingTrainedModel` (bool)
- **Logique simplifiée**:
  - Si `statistical_model.json` existe → mode "Modèle Personnel" (confidence basée sur échantillon)
  - Sinon → mode "Analyse Temps Réel" (estimations conservatives, confidence 0.3 max)
- **Nouvelles méthodes**: `_predictWithTrainedModel()` et `_predictRealTime()` remplacent 3 anciennes

#### 4. Interface Utilisateur - Clarifications

**insights_page.dart**:
- "Prédictions ML" → "Évaluation des Risques"
- Sous-titre dynamique: "📊 Modèle statistique personnel" / "⚡ Analyse en temps réel"
- "Déclencheurs Identifiés" → "📊 Corrélations Statistiques (30j)"
- Description: "Basé sur vos données récentes uniquement"
- **Limites zone triggers**: Max 10 déclencheurs affichés, score >= 0.15, minimum 3 occurrences (était 2)

**risk_assessment_card.dart**:
- Utilise `ModelManager.isUsingTrainedModel` au lieu de `avgConfidence > 0.65` (arbitraire)
- Sous-titre honnête: "Basé sur votre modèle statistique personnel" / "Analyse en temps réel (entraînez le modèle pour personnaliser)"
- Suppression du message trompeur "Prédictions par IA"

#### 5. Terminologie Cohérente
- **Partout dans le code**: "Modèle statistique" remplace "ML" ou "IA"
- **Commentaires**: "Statistical models" remplace "ML models"
- **Logs**: Messages clairs sur le mode actif

### Dette Technique Réduite
✅ **-250 lignes** de code mort (Python path, heuristics fallback, ancienne logique)
✅ **Confusion utilisateur éliminée** (badges visuels clairs 📊⚡)
✅ **Historique training fonctionnel** (INSERT après chaque training)
✅ **Confidence honnête** (basée sur taille échantillon, pas fixe)
✅ **Surcharge info réduite** (10 triggers max au lieu de tous)
✅ **model_status_page.dart adapté** au nouveau schéma v11 (suppression model_name, f1_score, accuracy)

### Reste à Faire
- [ ] Supprimer assets/models/*.json si présents (code ne les charge plus)
- [ ] Ajouter section "Comment ça fonctionne" dans model_status_page.dart
- [ ] Tester avec vraies données utilisateur (actuellement demo data only)
- [ ] Documenter le nouveau format JSON v2.0 pour les développeurs

## 2026-01-30 (Consolidation - Hotfix) - Adaptation model_status_page.dart

### Changements
1. **Correction erreur runtime**: `type 'Null' is not a subtype of type 'String' in type cast`
2. **Adaptation au schéma v11**:
   - Suppression recherche par `model_name` dans `_trainingHistory` (colonne n'existe plus)
   - Utilisation de l'historique global au lieu de per-modèle
   - Suppression paramètre `f1Score` de `_buildModelExpansionTile()`
   - Affichage "X corrélations" au lieu de "F1: X%"
3. **Historique d'entraînement**:
   - Affichage de `correlation_count`, `meal_count`, `symptom_count`
   - Icône dynamique basée sur nombre de corrélations (vert si >10, orange sinon)
   - Titre générique "Entraînement statistique" (pas de nom de modèle)
4. **Validation**: App démarre sans erreur, page Model Status fonctionnelle

