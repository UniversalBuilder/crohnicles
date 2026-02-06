# Changelog

Toutes les modifications notables de Crohnicles seront documentées dans ce fichier.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/),
et ce projet adhère au [Semantic Versioning](https://semver.org/lang/fr/).

---

## [1.2.0] - 2026-02-06

### 🔐 Ajouté - Sécurité & RGPD
- **Chiffrement base de données** : AES-256 via SQLCipher
  - Toggle activation/désactivation dans Settings
  - Migration automatique unencrypted ↔ encrypted
  - Stockage sécurisé de la clé (flutter_secure_storage)
  - PBKDF2_HMAC_SHA512 avec 256,000 itérations
- **Export CSV RGPD** : Article 20 (droit à la portabilité)
  - Format UTF-8 BOM (Excel-compatible)
  - Partage mobile via sheet système
  - Sauvegarde desktop dans Documents/
  - Preview avec statistiques (count, taille estimée)
- **Suppression définitive** : Article 17 (droit à l'oubli)
  - Suppression DB + clé de chiffrement + fichiers temporaires
  - Action irréversible avec confirmation

### ✅ Ajouté - Validation des Saisies
- Classe `EventValidators` avec 10 méthodes de validation
- Validations strictes :
  - Dates : Max 2 ans ancienneté, pas de dates futures
  - Quantités : >0 et ≤2000g/ml
  - Sévérité : Échelle 1-10
  - Bristol Scale : Échelle 1-7
- SnackBar rouge standardisée pour erreurs
- Intégrations : MealComposerDialog, SymptomDialog, StoolEntryDialog

### 🤖 Ajouté - ML Training Status UI
- Widget `MLTrainingStatusCard` dans Tableau de Bord
- Affichage progression : X/30 repas, X/30 symptômes
- Barre de progression globale (%)
- Historique : Dernière date entraînement + nombre total
- Couleur dynamique : Vert (prêt), Orange (en cours), Gris (insuffisant)
- Message aide si données insuffisantes

### 🛠️ Corrigé
- **TimePicker format 24h** : Respect paramètres système (MediaQuery.alwaysUse24HourFormat)
- **25 erreurs de compilation** : Corrections diverses héritées v1.1

### 📚 Documentation
- Mise à jour README.md : Section "Sécurité & Confidentialité" complète
- Mise à jour TODO.md : Étapes 1-5 marquées complétées
- Mise à jour architecture_state.md : 3 nouvelles entrées (Étapes 2, 4, 5)
- Nouveau fichier CHANGELOG.md

### 🔧 Technique
- Dépendances ajoutées :
  - `flutter_secure_storage: ^9.2.2`
  - `sqlcipher_flutter_libs: ^0.6.1`
  - `share_plus: ^10.1.3`
- Nouveau service : `EncryptionService` (170 LOC)
- Nouveau service : `CsvExportService` (200 LOC)
- Nouvelles méthodes DatabaseHelper : 6 méthodes stats ML
- Nouveau widget : `MLTrainingStatusCard` (350 LOC)

---

## [1.1.0] - 2026-01-15

### ✨ Ajouté - UX & Interface
- **Wizard symptômes 3 étapes** : Navigation progressive
  - Étape 1 : Drill-down interactif par zone
  - Étape 2 : Sliders d'intensité
  - Étape 3 : Récapitulatif avec silhouette
- **Silhouette abdomen** : Image PNG avec Transform.scale + Alignment
- **Regroupement événements timeline** : Events simultanés groupés (même minute)
- **Corrections mode sombre** :
  - meal_detail_dialog.dart
  - methodology_page.dart
  - Amélioration contraste (surfaceContainerHigh)
- **Correction overflow** : Graphique localisation douleurs (Flexible + SingleChildScrollView)

### 🔐 Ajouté - Sécurité
- **Sécurisation API OpenWeather** : Gestion via flutter_dotenv
  - Création de `.env` (git-ignored)
  - Création de `.env.example` (template versionné)
  - Suppression API key hardcodée

### 🧹 Nettoyage
- Suppression code mort :
  - `_buildWeatherCorrelationsBarChart`
  - `_buildZoneSeverityRow`
- Suppression imports inutilisés (main.dart)

### 📚 Documentation
- Création de TODO.md (plan 8 étapes)
- Création de docs/CALCULATIONS.md (formules transparentes)
- Mise à jour README.md : Section "Architecture"

---

## [1.0.0] - 2026-01-01

### 🎉 Release Initiale

#### Fonctionnalités Principales
- **Gestion Repas** :
  - Compositeur intelligent 4 onglets
  - Intégration OpenFoodFacts (scan + recherche)
  - Autocomplétion locale
  - Tags flexibles
- **Suivi Symptômes** :
  - Taxonomie médicale 5 niveaux
  - Contexte automatique (météo)
  - Analyse interactive
- **Journal Selles** :
  - Bristol Stool Scale (types 1-7)
  - Urgence, fréquence, sang/mucus
- **Insights & Prédictions** :
  - Analyse statistique bayésienne
  - Mode temps réel (<30 repas)
  - Entraînement modèle (≥30 repas + 20 symptômes)
  - Graphiques fl_chart
- **Settings** :
  - Thème Light/Dark
  - Logs debug
  - Export CSV (basique)

#### Architecture
- Flutter 3.38.7 / Dart 3.10.7
- Material Design 3
- SQLite (sqflite)
- Provider (state management)
- TensorFlow Lite (ML on-device)

#### Plateformes
- Android (API 24+)
- iOS (14.0+)
- Windows
- macOS
- Linux (expérimental)
- Web (expérimental)

---

## Format des Entrées

### Types de Changements
- **Ajouté** : Nouvelles fonctionnalités
- **Modifié** : Changements de fonctionnalités existantes
- **Déprécié** : Fonctionnalités bientôt supprimées
- **Supprimé** : Fonctionnalités retirées
- **Corrigé** : Corrections de bugs
- **Sécurité** : Vulnérabilités corrigées

### Emojis Guide
- 🎉 Release majeure
- ✨ Nouvelle fonctionnalité
- 🔐 Sécurité
- 🛠️ Correction bug
- 📚 Documentation
- 🧹 Nettoyage code
- ⚡ Performance
- 🎨 UI/UX
- 🤖 Machine Learning
- 📊 Analytics
