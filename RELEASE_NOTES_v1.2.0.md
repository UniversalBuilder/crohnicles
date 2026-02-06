# 🎉 Crohnicles v1.2.0 - Production Ready

**Date de release :** 6 février 2026  
**Plan de Consolidation :** ✅ 8/8 Étapes complétées (100%)

---

## 🌟 Nouveautés Majeures

### 🔒 Sécurité & RGPD
- **Encryption AES-256** : Base de données chiffrée avec SQLCipher
  - Toggle dans Settings pour activer/désactiver
  - Migration automatique et réversible
  - Clés stockées dans secure storage (hardware-backed sur Android)
- **Validation des saisies** : Classe `EventValidators` avec 10 méthodes de validation
  - Dates (max 2 ans dans le passé)
  - Sévérité/Bristol (échelles 1-10 et 1-7)
  - Quantités (>0 et ≤2000g/ml)
  - Messages d'erreur contextuels en français
- **Export CSV + RGPD** : Service `CsvExportService` avec UTF-8 BOM
  - Format Excel-compatible
  - Partage multi-plateforme (Android sheet, Desktop Documents)
  - Preview avec statistiques (count, taille estimée)
- **Suppression RGPD** : Bouton "Réinitialiser TOUTES les données"
  - Suppression complète : DB, encrypted, clés, WAL, SHM

### 🤖 Machine Learning
- **ML Training Status UI** : Widget `MLTrainingStatusCard` dans insights_page
  - Progression globale : (repas + symptômes) / 60 × 100%
  - 2 compteurs détaillés : Repas (X/30) et Symptômes (X/30)
  - Historique : Dernière date entraînement + nombre total
  - Couleur dynamique : Vert (≥30), Orange (50-99%), Gris (<50%)
- **Service d'entraînement** : `TrainingService` pour ML on-device
  - Entraînement autonome (pas de dépendance Python/Windows)
  - 3 modèles : Douleur, Ballonnement, Diarrhée
  - Split 80/20 (train/test) avec métriques de qualité

### 🧪 Tests & Qualité
- **111 tests unitaires** : 4 fichiers de tests (validation, CSV, encryption, ML)
  - `test/validation_test.dart` : 49 tests
  - `test/csv_export_test.dart` : 40 tests
  - `test/encryption_test.dart` : Tests
  - `test/ml_training_stats_test.dart` : 22 tests
- **flutter analyze** : 194 → 91 warnings (-53% réduction)
  - Remplacement 66 `print()` par `debugPrint()`
  - Suppression deprecated colors
  - Nettoyage imports inutilisés et code mort

### 🚀 CI/CD & Documentation
- **GitHub Actions** : Pipeline multi-plateforme (`.github/workflows/ci.yml`)
  - Job Analyze : flutter analyze, dart format, pub outdated
  - Job Test : flutter test --coverage + upload Codecov
  - Job Build : Android APK, iOS Runner.app, Windows Release
  - Triggers : Push/PR sur main et develop
- **Documentation complète** :
  - README.md : Instructions installation + screenshots
  - TODO.md : Priorités v1.3 (ML UI, Widget météo, Export PDF)
  - CHANGELOG.md : Historique versions
  - architecture_state.md : Journal architectural détaillé (Étapes 1-8)
  - docs/CALCULATIONS.md : Formules et seuils (corrélations météo)

---

## 📊 Métriques Qualité

| Métrique | État |
|----------|------|
| **Compilation** | ✅ 0 erreurs |
| **Tests Unitaires** | ✅ 111 passing |
| **flutter analyze** | ✅ 91 warnings (acceptable) |
| **Sécurité** | ✅ AES-256 + Validation |
| **RGPD** | ✅ Export CSV + Suppression complète |
| **CI/CD** | ✅ GitHub Actions multi-plateforme |
| **Documentation** | ✅ README, TODO, CHANGELOG, architecture_state |

---

## 🛠️ Corrections & Améliorations

### Étape 1 : Compilation (25 erreurs corrigées)
- Remplacement strings → EventType enum (16 occurrences)
- Correction erreurs generateDemoData()

### Étape 2 : Encryption (8 bugs résolus)
- Fix encryption hangs (delete temp files)
- Fix onCreate errors (manual table creation)
- Fix insights infinite spinner (try/catch garantit)
- Fix SQLITE_READONLY_DBMOVED (full navigation reset)

### Étape 3 : Validation (10 validateurs)
- Date validation (max 2 ans, future dates)
- Severity/Bristol scale validation
- Quantity validation (>0, ≤2000g/ml)
- Required text (1-200 chars)

### Étape 4 : Export CSV (40 tests)
- UTF-8 BOM encoding (Excel Windows)
- Metadata parsing (foods, zones, Bristol, weather)
- RGPD compliance verification

### Étape 5 : ML Status UI (22 tests)
- Widget MLTrainingStatusCard
- DatabaseHelper méthodes : getMLTrainingStats(), getMealCount(), getSevereSymptomCount()
- Couleur dynamique selon progression

### Étape 6 : Documentation
- README.md mis à jour
- TODO.md nettoyé (priorités v1.3)
- CHANGELOG.md créé
- architecture_state.md (8 sections détaillées)

### Étape 7 : Tests (111 tests)
- Stratégie : Unit tests (pure logic) vs Integration tests (device-only)
- Validation complète : EventValidators, CsvExportService, Encryption, ML Stats

### Étape 8 : GitHub Prep (93 warnings corrigés)
- Remplacement 66 print() → debugPrint()
- Suppression deprecated colors (app_theme.dart)
- Nettoyage imports inutilisés
- GitHub Actions CI/CD configuré

---

## 📱 Installation

### Prérequis
- Flutter 3.27.2+ / Dart 3.10.7+
- Android Studio / Xcode (selon plateforme)
- OpenWeather API key (gratuite) : https://openweathermap.org/api

### Setup
```bash
# 1. Cloner le repo
git clone https://github.com/UniversalBuilder/crohnicles.git
cd crohnicles

# 2. Installer les dépendances
flutter pub get

# 3. Créer .env (copier .env.example)
cp .env.example .env
# Éditer .env et remplir OPENWEATHER_API_KEY

# 4. Lancer l'app
flutter run
```

---

## 🧪 Tests

```bash
# Tests unitaires (111 tests)
flutter test test/validation_test.dart test/csv_export_test.dart test/encryption_test.dart test/ml_training_stats_test.dart

# Tous les tests
flutter test

# Avec couverture
flutter test --coverage

# Analyse code
flutter analyze
```

---

## 🚀 Build

```bash
# Android APK
flutter build apk --release

# iOS (macOS uniquement)
flutter build ios --release --no-codesign

# Windows
flutter build windows --release
```

---

## 📄 License

MIT License - Voir [LICENSE.md](LICENSE.md)

---

## 🤝 Contribution

Voir [CONTRIBUTORS.md](CONTRIBUTORS.md) pour guidelines de contribution.

---

## 📞 Support

- **Issues** : https://github.com/UniversalBuilder/crohnicles/issues
- **Discussions** : https://github.com/UniversalBuilder/crohnicles/discussions

---

## 🎯 Roadmap v1.3

Voir [TODO.md](TODO.md) pour les priorités :
- **Option A** : Finaliser ML UI (bouton entraînement, dialog progress)
- **Option B** : Widget météo timeline
- **Option C** : Export PDF rapport RGPD

---

**🌟 Thank you for using Crohnicles!**
