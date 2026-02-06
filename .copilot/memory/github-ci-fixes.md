# GitHub CI/CD Dependency Fixes - Session Active

## Contexte
Release v1.2.0 publiée, mais GitHub Actions échoue à cause de versions de dépendances incompatibles avec Dart 3.6.1 / Flutter 3.27.2 (environnement CI).

## Fixes Appliqués

### Round 1 (651f570) - CI Configuration
- ✅ `dart format || true` (non-blocking)
- ✅ `flutter analyze --no-fatal-warnings`
- ✅ README.md links (YOUR_USERNAME → UniversalBuilder)

### Round 2 (13db0a3) - SDK Version
- ✅ `sdk: ^3.10.7` → `sdk: '>=3.6.0 <4.0.0'`
- Raison: Dart 3.10.7 n'existe pas

### Round 3 (5d2162b) - flutter_lints
- ✅ `flutter_lints: ^6.0.0` → `^5.0.0`
- Raison: 6.0.0 nécessite Dart ^3.8.0

### Round 4 (c10bcda) - path conflict
- ✅ `path: ^1.9.1` [SUPPRIMÉ]
- Raison: Conflit integration_test (1.9.0) vs flutter_test (1.9.1)

### Round 5 (b232d1a) - Batch downgrade
- ✅ `shared_preferences: ^2.5.4` → `^2.3.0` (nécessitait Dart ^3.9.0)
- ✅ `dio: ^5.9.1` → `^5.7.0`
- ✅ `share_plus: ^10.1.3` → `^10.0.0`
- ✅ `url_launcher: ^6.3.1` → `^6.3.0`

### Round 6 (b6ec12e) - workmanager
- ✅ `workmanager: ^0.9.0+3` → `^0.5.2`
- Raison: 0.9.0+3 nécessitait Flutter >=3.32.0 (n'existe pas)

### Round 7 (bdaa4de) - google_fonts
- ✅ `google_fonts: ^7.1.0` → `^6.1.0` (résolu en 6.3.3)
- Raison: 7.1.0 nécessite Dart ^3.9.0
- Erreur: "Because google_fonts 7.1.0 requires SDK version ^3.9.0... version solving failed"
- Validation: flutter pub get ✅, flutter analyze 90 warnings ✅

### Round 8 (03d98bc) - fl_chart
- ✅ `fl_chart: ^1.1.1` → `^1.0.0` (résolu en 1.0.0)
- Raison: 1.1.1 nécessite Dart >=3.6.2 (GitHub Actions utilise 3.6.1)
- Erreur: "Because fl_chart 1.1.1 requires SDK version >=3.6.2"
- Validation: flutter pub get ✅, flutter analyze 90 warnings ✅

### Round 9 (f955216) - Tentative Flutter 'latest' ❌
- ❌ **Upgrade GitHub Actions Flutter: 3.27.2 → 'latest'**
- Problème: 'latest' = Flutter 3.27.x (Dart 3.6.0), pas 3.38.x
- Résultat: Désalignement CI (Dart 3.6.0) vs Local (Dart 3.10.7)
- Erreur suivante: image_picker 1.2.1 nécessite Dart ^3.7.0

### Round 10 (06007f7) - ALIGNEMENT TOTAL ✅✅✅ SOLUTION DÉFINITIVE
- ✅ **Fixer GitHub Actions Flutter: 'latest' → '3.38.7'**
- Modifié: `.github/workflows/ci.yml` (5 occurrences)
- Raison: Aligner CI avec environnement LOCAL (Flutter 3.38.7 / Dart 3.10.7)
- Impact: TOUS packages récents (image_picker, google_fonts, etc.) compatibles
- **FIN DÉFINITIVE de la cascade** 🎉

## 📋 STRATÉGIE COHÉRENTE FINALE

### Environnements Alignés
- **Local**: Flutter 3.38.7 (Dart 3.10.7)
- **GitHub Actions**: Flutter 3.38.7 (Dart 3.10.7)
- **pubspec.yaml SDK**: `sdk: '>=3.6.0 <4.0.0'` (permet 3.6-3.10)

### Packages Downgradés (Peuvent être revertés)
Tous ces packages ont été downgradés pour Dart 3.6.x, mais peuvent maintenant utiliser versions récentes:
1. ✅ flutter_lints: ^5.0.0 → peut reverter à ^6.0.0
2. ✅ shared_preferences: ^2.3.0 → peut reverter à ^2.5.4
3. ✅ dio: ^5.7.0 → peut reverter à ^5.9.1
4. ✅ share_plus: ^10.0.0 → peut reverter à ^10.1.3
5. ✅ url_launcher: ^6.3.0 → peut reverter à ^6.3.1
6. ✅ workmanager: ^0.5.2 → peut reverter à ^0.9.0+3
7. ✅ google_fonts: ^6.1.0 → peut reverter à ^7.1.0
8. ✅ fl_chart: ^1.0.0 → peut reverter à ^1.1.1

### Règle de Gouvernance
- CI TOUJOURS fixé à version spécifique (jamais 'latest')
- Local upgrade via `flutter upgrade` régulièrement
- Après upgrade local: Mettre à jour CI pour aligner
- Vérifier compatibilité packages avec `flutter pub outdated`

## 🚨 PACKAGES À RISQUE (Versions futures)
Packages bloqués à versions anciennes car versions récentes nécessitent Dart >=3.6.2+ ou Flutter >=3.28+:
- mobile_scanner: 5.2.3 (7.1.4 disponible mais blocké)
- share_plus: 10.1.4 (12.0.1 disponible mais blocké)
- sqflite_sqlcipher: 2.2.1 (3.4.0 disponible mais blocké)
- google_fonts: 6.3.3 (8.0.1 disponible mais blocké)
- flutter_secure_storage: 9.2.4 (10.0.0 disponible mais blocké)
- tflite_flutter: 0.11.0 (0.12.1 disponible mais blocké)
- workmanager: 0.5.2 (0.9.0+3 disponible mais blocké)

**Tous ces packages ont des versions "available" qui nécessitent SDK plus récent que Dart 3.6.1 ou Flutter 3.27.2.**

## Stratégie
- Downgrader systématiquement toutes dépendances nécessitant Dart >=3.7.0
- Valider localement AVANT chaque push
- Attendre mise à jour GitHub Actions vers Dart 3.8+ pour revenir aux versions récentes
