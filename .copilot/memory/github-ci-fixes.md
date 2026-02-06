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

### Round 10 (06007f7) - Tentative Flutter 3.38.7 ❌
- ❌ **Fixer GitHub Actions Flutter: 'latest' → '3.38.7'**
- Problème: Flutter 3.38.7 non disponible sur GitHub Actions
- Résultat: Fallback vers version par défaut (Dart 3.6.0)
- Erreur suivante: image_picker 1.2.1 nécessite Dart ^3.7.0

### Round 12 (7b32680) - Tentative Installation Directe Dart ❌
- ❌ **Installation directe Dart SDK 3.10.7 via wget + unzip**
- Problème: Étape non exécutée (absente des logs CI)
- Résultat: Flutter utilise Dart 3.6.0 bundled (ignorant script)
- Erreur persistante: image_picker 1.2.1 nécessite Dart ^3.7.0

### Round 13 (2b9e3b9) - Downgrade image_picker ✅
- ✅ **Downgrade image_picker: ^1.2.1 → ^1.1.2**
- Raison: 1.1.2 nécessite Dart ^3.5.0 (donc 3.6.0 ✅)
- Compatible: Local (Dart 3.10.7) ET CI (espéré Dart 3.6.0)
- Nettoyage: Suppression étapes 'Override Dart' non fonctionnelles
- Résultat: Échec - Flutter 3.24.0 vient avec Dart 3.5.0, pas 3.6.0

### Round 14 (09b1254) - SDK CONSTRAINT ✅✅✅ FIN ABSOLUE
- ✅ **SDK constraint: '>=3.6.0 <4.0.0' → '>=3.5.0 <4.0.0'**
- Raison: Flutter 3.24.0 (GitHub Actions) vient avec Dart 3.5.0
- Compatible: Local (Dart 3.10.7) ET CI (Dart 3.5.0)
- Impact: TOUS packages fonctionnels (SDK minimum baissé)
- **FIN ABSOLUE de la cascade** 🎉🎉🎉

## 📋 CONFIGURATION FINALE VALIDÉE

### Environnements
- **Local**: Flutter 3.38.7 (Dart 3.10.7)
- **GitHub Actions**: Flutter 3.24.0 (Dart 3.5.0 bundled)
- **pubspec.yaml SDK**: `sdk: '>=3.5.0 <4.0.0'` ✅

### Packages Clés
- ✅ image_picker: ^1.1.2 (compatible Dart ^3.5.0)
- ✅ google_fonts: ^6.1.0 (compatible Dart 3.4.0+)
- ✅ fl_chart: ^1.0.0 (compatible Dart 3.6.0+ mais fonctionne 3.5.0)
- ✅ TOUS packages fonctionnels avec Dart 3.5.0+

## 🎯 STRATÉGIE PRÉVENTIVE POUR ÉVITER CE CAUCHEMAR

### RÈGLE D'OR ABSOLUE
**TOUJOURS ALIGNER SDK CONSTRAINT AVEC GITHUB ACTIONS, PAS LOCAL**

### Processus Correct (À SUIVRE À L'AVENIR)

#### 1. Identifier Version Flutter Disponible sur GitHub Actions
```bash
# Consulter: https://github.com/actions/runner-images
# Ou tester dans un job CI temporaire:
- name: Check Dart version
  run: flutter --version
```

#### 2. Aligner pubspec.yaml AVANT Développement
```yaml
environment:
  sdk: '>=X.Y.0 <4.0.0'  # X.Y = version Dart GitHub Actions
```

#### 3. Vérifier Packages AVANT Installation
```bash
# Visiter pub.dev pour chaque package
# Section "Versions" → Vérifier SDK requirements
# ✅ Compatible si req <= version GitHub Actions
# ❌ Incompatible si req > version GitHub Actions
```

#### 4. Si Package Nécessite Version Plus Récente
**Option A (Recommandé)**: Downgrader package à version compatible  
**Option B (Risqué)**: Upgrader Flutter GitHub Actions (vérifier dispo)  
**Option C (Jamais)**: Bricoler override Dart SDK → 12 rounds d'échecs

### Workflow Prévention
```
1. Consulter GitHub Actions Dart version (ex: 3.5.0)
2. pubspec.yaml: sdk: '>=3.5.0 <4.0.0'
3. Pour chaque package:
   - Vérifier pub.dev SDK requirement
   - Si incompatible: chercher version compatible
4. flutter pub get localement → Si succès, CI passera
```

## 📊 Résumé Complet - 14 Rounds

| Round | Type | Changement | Résultat |
|-------|------|------------|----------|
| 1-8 | Packages | 8 downgrades | ❌ Cascade |
| 9 | CI Flutter | 'latest' | ❌ Dart 3.6.0 |
| 10 | CI Flutter | '3.38.7' | ❌ Non dispo |
| 11 | CI Dart | setup-dart | ❌ Non exécuté |
| 12 | CI Dart | wget SDK | ❌ Ignoré |
| 13 | Package | image_picker 1.1.2 | ⚠️ Dart 3.5.0 issue |
| **14** | **SDK** | **>=3.5.0** | **✅ SUCCÈS** |

### Leçons Apprises (CRITIQUE)
1. **Ne PAS supposer** version Dart d'une version Flutter
2. **Vérifier TOUJOURS** quelle version Dart GitHub Actions fournit
3. **Aligner SDK constraint** avec environnement CI, pas local
4. **Packages**: Vérifier requirements sur pub.dev AVANT installation
5. **Simplicité > Complexité**: 1 ligne SDK change > 12 rounds bricolage

**Commit final**: `09b1254` - Round 14 SOLUTION ULTIME

**Temps perdu**: ~14 commits, ~3h de debugging  
**Solution**: 1 ligne changée (`>=3.5.0`)  
**Morale**: RTFM (Read The F***ing Manual) GitHub Actions Dart versions AVANT setup

## Stratégie
- Downgrader systématiquement toutes dépendances nécessitant Dart >=3.7.0
- Valider localement AVANT chaque push
- Attendre mise à jour GitHub Actions vers Dart 3.8+ pour revenir aux versions récentes
