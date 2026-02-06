# 🚨 STRATÉGIE ANTI-CAUCHEMAR CI/CD

## Le Problème Qu'on Vient de Vivre (14 Rounds !)

**Root Cause**: Désalignement versions Local vs GitHub Actions  
**Symptôme**: Cascade infinie d'erreurs de dépendances  
**Temps perdu**: ~3h, 14 commits  
**Solution**: 1 ligne changée (`sdk: '>=3.5.0 <4.0.0'`)

---

## ✅ PROCESSUS SIMPLE POUR ÉVITER CE CAUCHEMAR

### ÉTAPE 1 : Identifier Version Dart de GitHub Actions (1 min)

**Méthode A** : Consulter documentation officielle  
👉 https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md  
Chercher "Flutter" → Noter version Dart bundled

**Méthode B** : Créer job CI temporaire test
```yaml
# .github/workflows/check-versions.yml
name: Check Versions
on: workflow_dispatch
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
      - run: flutter --version
```

**Résultat**: Noter version Dart (ex: 3.5.0)

---

### ÉTAPE 2 : Configurer pubspec.yaml AVANT Développement

```yaml
# pubspec.yaml
environment:
  sdk: '>=X.Y.0 <4.0.0'  # X.Y = version Dart GitHub Actions
```

**Exemple Concret**:
- GitHub Actions : Flutter 3.24.0 → Dart 3.5.0
- pubspec.yaml : `sdk: '>=3.5.0 <4.0.0'` ✅

**⚠️ JAMAIS** :
- ❌ `sdk: '>=3.10.7 <4.0.0'` (version locale)
- ❌ `sdk: '^3.6.0'` (version imaginaire)

---

### ÉTAPE 3 : Vérifier Packages AVANT Installation

Pour chaque nouveau package :

1. **Visiter pub.dev** : https://pub.dev/packages/PACKAGE_NAME
2. **Onglet "Versions"** → Cliquer dernière version
3. **Section "SDK"** → Noter requirement (ex: ">=3.7.0")
4. **Comparer** :
   - ✅ Si req <= Dart GitHub Actions → OK installer
   - ❌ Si req > Dart GitHub Actions → Chercher version compatible

**Exemple** :
```
GitHub Actions: Dart 3.5.0
Package image_picker 1.2.1 : Nécessite Dart >=3.7.0
❌ INCOMPATIBLE

Solution: Chercher version compatible
image_picker 1.1.2 : Nécessite Dart >=3.5.0
✅ COMPATIBLE
```

---

### ÉTAPE 4 : Valider Localement

```bash
# 1. Installer dépendances
flutter pub get

# 2. Si erreur SDK version
# → Vérifier que pubspec.yaml SDK match GitHub Actions
# → PAS ta version locale

# 3. Si succès local
# → CI devrait passer (même Dart version)
```

---

## 🎯 CHECKLIST AVANT PUSH

- [ ] `pubspec.yaml` SDK = version Dart GitHub Actions
- [ ] `flutter pub get` passe localement
- [ ] Tous packages pub.dev compatible avec Dart GitHub Actions
- [ ] `.github/workflows/ci.yml` Flutter version stable connue

**Si tous ✅ → Push → CI passe (99.9% chance)**

---

## 🔧 RÉSOLUTION RAPIDE SI ÉCHEC CI

### Erreur Type 1 : "SDK version solving failed"
```
Because package X requires SDK version >=A.B.C
```

**Solution** :
1. Visiter pub.dev/packages/X
2. Trouver version compatible avec Dart GitHub Actions
3. `package_name: ^VERSION_COMPATIBLE` dans pubspec.yaml

### Erreur Type 2 : "requires SDK version >=3.X.0"
```
Because crohnicles requires SDK version >=3.X.0
```

**Solution** :
1. Vérifier Dart version GitHub Actions (ex: 3.5.0)
2. pubspec.yaml : `sdk: '>=3.5.0 <4.0.0'`

---

## 📊 Workflow Recommandé (Template)

```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      # Utiliser version STABLE et CONNUE
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'  # Version testée
          channel: 'stable'
          cache: true
      
      # Afficher version pour debug
      - name: Flutter version
        run: flutter --version
      
      - run: flutter pub get
      - run: flutter test
      - run: flutter build apk --release
```

---

## 🚫 NE JAMAIS FAIRE

1. ❌ `flutter-version: 'latest'` (ambigu, change)
2. ❌ Installer packages sans vérifier pub.dev SDK req
3. ❌ Aligner `pubspec.yaml` SDK avec version locale
4. ❌ Bricoler override Dart SDK dans CI (12 rounds échecs)
5. ❌ Supposer qu'une version Flutter a une version Dart spécifique

---

## ✅ TOUJOURS FAIRE

1. ✅ Fixer version Flutter spécifique dans CI (`3.24.0`)
2. ✅ Vérifier quelle version Dart ça bundle
3. ✅ Aligner `pubspec.yaml` SDK avec cette version
4. ✅ Vérifier pub.dev pour chaque nouveau package
5. ✅ Tester `flutter pub get` localement avant push

---

## 💡 Philosophie

**L'environnement CI est LA source de vérité, pas ton local.**

- Local : Environnement de développement (peut être bleeding-edge)
- CI : Environnement de production (doit être stable)
- **Aligne le code avec CI, pas CI avec le code**

---

## 📞 Ressources

- **GitHub Actions images** : https://github.com/actions/runner-images
- **pub.dev** : https://pub.dev (vérifier SDK requirements)
- **Flutter releases** : https://docs.flutter.dev/release/archive
- **Dart releases** : https://dart.dev/get-dart/archive

---

**En Résumé** : 5 minutes de vérification AVANT = 3 heures de debug ÉVITÉES
