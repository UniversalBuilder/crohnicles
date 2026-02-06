# 🚫 DÉCISION : GitHub Actions CI/CD DÉSACTIVÉ

**Date** : 6 février 2026  
**Commit** : 7410ddb  
**Issue** : #17 (18 rounds cascade failures)

## Contexte

Après la publication de la release v1.2.0 sur GitHub, tentative d'intégration CI/CD avec GitHub Actions.

**Résultat** : Échec catastrophique après 18 rounds de debugging (~5h perdues).

## Problème Technique

**Root Cause** : Incompatibilité Flutter/Dart versions entre Local et GitHub Actions

- **Local** : Flutter 3.38.7 + Dart 3.10.7 (fonctionne parfaitement)
- **GitHub Actions** : Flutter 3.24.0 + Dart 3.5.0/3.6.0 (instable, incompatible packages modernes)

**Cascade d'erreurs** (18 rounds) :
1. Rounds 1-8 : Downgrades packages individuels (flutter_lints, shared_preferences, workmanager, etc)
2. Rounds 9-12 : Tentatives infructueuses upgrade Dart SDK en CI
3. Round 13 : Downgrade image_picker
4. Round 14 : SDK constraint adjustment (>=3.5.0)
5. Round 15 : Overrides image_picker_linux/windows
6. Round 16 : Downgrade sqflite_common_ffi_web
7. Round 17 : **STRATÉGIE RADICALE** - Mass downgrades + overrides (famille sqflite)
8. Round 18 : Override intl (Flutter SDK pinning conflict)
9. **Round 19 (décision STOP)** : fl_chart incompatible (nécessite Dart 3.6.2+)

**Complications** :
- Dart version GitHub Actions instable (3.5.0 → 3.6.0 durant debugging)
- Flutter SDK versions = intl versions différentes pinnées (0.19.0 vs 0.20.2)
- Packages modernes nécessitent Dart 3.7.0+ (incompatible Flutter 3.24.0 CI)

## Décision

**DÉSACTIVATION COMPLÈTE CI/CD GitHub Actions**

**Rationale** :
1. ✅ Projet **fonctionne localement** (Flutter 3.38.7)
2. ✅ Release v1.2.0 **déjà publiée** et stable
3. ✅ Builds Android/iOS **possibles manuellement**
4. ❌ CI/CD = **luxe**, PAS nécessité
5. ❌ Temps debug CI/CD > Bénéfice validation auto
6. ❌ Cascade infinie sans garantie de succès (Round 19+ probable)

## Actions Prises

### 1. Désactivation CI
- `.github/workflows/ci.yml` → `ci.yml.disabled`
- Plus de runs GitHub Actions sur push

### 2. Documentation Build Enhanced
**README.md** section améliorée avec :
- **Android** : Instructions APK/AAB + signing + distribution
- **iOS** : Guide complet Xcode + provisioning + troubleshooting
- **Ressources officielles** : Links Flutter + Apple guides

### 3. Nettoyage Repo
- CI debugging docs archivés : `.copilot/memory/ARCHIVE_github-ci-18rounds.md`
- Roadmap mise à jour : CI/CD ✗ supprimé, repo ✓ publié
- Badges ajustés : Android | iOS prioritaires

## Solution Alternative (Si CI/CD requis à l'avenir)

### Option A : Upgrade Flutter CI (Quand disponible)
- Attendre Flutter 3.38+ disponible sur GitHub Actions runners
- Re-enable workflow avec `flutter-version: '3.38'`
- Tester sans downgrades

### Option B : Self-Hosted Runner
- Configurer runner local avec Flutter 3.38.7
- Control total environnement
- Coût : infrastructure + maintenance

### Option C : GitLab CI / CircleCI
- Tester autre CI provider avec Flutter 3.38+ support
- Migration effort considérable

## Philosophie Adoptée

**"Focus Features > Infrastructure"**

- Priorité : Développement fonctionnalités utilisateur
- CI/CD utile mais PAS bloquant
- Validation locale (tests + flutter analyze) suffit
- Release manuelle acceptable pour projet solo/petit team

## Impact Utilisateur

**AUCUN** - L'utilisateur ne voit pas le CI/CD. Le projet reste :
- ✅ Fonctionnel localement
- ✅ Buildable Android/iOS
- ✅ Publiable manuellement
- ✅ Code quality maintenue (local testing)

## Lessons Learned

1. **Vérifier TOUJOURS** versions Flutter/Dart CI AVANT setup
2. **Environnements CI instables** = Cascade garantie
3. **CI/CD ≠ Projet réussi** - Code quality > Infrastructure
4. **Quand cascade > 3 rounds** → STOP et réévaluer approche
5. **dependency_overrides massifs** = Red flag (environnement incompatible)

## Conclusion

**Décision stratégique pragmatique** : Arrêter hémorragie temps/énergie sur CI/CD dysfonctionnel.

Le projet Crohnicles reste **fonctionnel, déployable et maintenable** sans GitHub Actions.

---

**Statut** : CLOSED  
**Next Steps** : Continuer développement features v1.3 (Export PDF, tests locaux)
