# 📸 Guide de Capture de Screenshots

Ce guide explique comment capturer automatiquement ou manuellement des screenshots de Crohnicles pour la documentation (README).

## 🎯 Screenshots Requis

Pour le README, nous avons besoin des screenshots suivants :

1. **Timeline (Page d'accueil)** - `01_timeline.png`
   - Vue principale avec événements
   - Montre le FAB (bouton +)
   
2. **Compositeur de Repas** - `02_meal_composer.png`
   - Dialog de saisie de repas
   - Affiche les 4 onglets (Pain, Protéines, Légumes, Boissons)
   
3. **Insights & Graphiques** - `03_insights.png`
   - Page d'analyse avec graphiques
   - Timeline, PieChart, BarChart visibles
   
4. **Calendrier** - `04_calendar.png`
   - Vue calendrier mensuel
   - Événements colorés par type
   
5. **Settings & About** - `05_settings.png`
   - Page des paramètres
   - Section "À propos" visible

---

## 🤖 Méthode Automatique (Mobile)

### Prérequis
- **Émulateur Android Studio** (recommandé : Pixel 6 API 34) OU Simulateur iOS
- Flutter SDK configuré

### Étapes

**Android** (PRIORITAIRE) :
```bash
# 1. Lister les émulateurs disponibles
flutter emulators

# 2. Lancer l'émulateur (exemple: Pixel_6_API_34)
flutter emulators --launch Pixel_6_API_34

# 3. Vérifier que l'appareil est détecté
flutter devices

# 4. Capturer les screenshots
flutter test integration_test/screenshot_test.dart

# Les screenshots seront sauvegardés dans docs/screenshots/
```

**iOS** (nécessite macOS) :
```bash
# 1. Lancer le simulateur
open -a Simulator

# 2. Vérifier l'appareil
flutter devices

# 3. Capturer les screenshots
flutter test integration_test/screenshot_test.dart
```

Les screenshots seront automatiquement sauvegardés dans `docs/screenshots/`.

---

## 🖱️ Méthode Manuelle (Windows/Desktop)

La méthode manuelle est recommandée pour Windows car integration_test ne supporte pas nativement la capture d'écran sur desktop.

### Étapes

1. **Lancer l'application en mode debug**
```powershell
flutter run -d windows
```

2. **Naviguer dans l'app et capturer**

Utilisez l'un de ces outils :

#### Option A : Windows Snipping Tool (Win + Shift + S)
1. Positionnez la fenêtre de l'app
2. Appuyez sur `Win + Shift + S`
3. Sélectionnez la zone à capturer
4. Sauvegardez dans `docs\screenshots\` avec le bon nom

#### Option B : ShareX (Recommandé)
1. Installez [ShareX](https://getsharex.com/)
2. Configurez la destination : `docs\screenshots\`
3. Utilisez le raccourci (`Ctrl + Print Screen`)
4. Renommez les fichiers selon la convention

#### Option C : Script PowerShell
```powershell
# Utilise le script fourni
.\scripts\capture_screenshots.ps1 -device windows -outputDir "docs\screenshots"
```

### Checklist de Navigation

1. ✅ **Timeline** : Page d'accueil par défaut
   - Attendez le chargement complet
   - Capturez la vue avec événements

2. ✅ **Compositeur de Repas** :
   - Cliquez sur le bouton `+` (FAB)
   - Sélectionnez "Repas"
   - Capturez le dialog avec les 4 onglets

3. ✅ **Insights** :
   - Naviguez vers l'onglet "Insights" (icône graphique)
   - Attendez le chargement des graphiques
   - Capturez la vue complète

4. ✅ **Calendrier** :
   - Naviguez vers l'onglet "Calendrier"
   - Capturez la vue mensuelle

5. ✅ **Settings** :
   - Cliquez sur l'icône Settings (⚙️)
   - Scroll jusqu'à la section "À propos"
   - Capturez la vue

---

## 📐 Recommandations Techniques

### Résolution
- **Android** : 1080x2400 (Pixel 6) ou 1080x1920 (portrait standard)
- **iOS** : 1170x2532 (iPhone 14 Pro)
- **Desktop** (optionnel) : 1280x720
- Format : PNG (meilleure qualité)

### Cadrage
- Capturer UNIQUEMENT la fenêtre de l'app (pas le desktop)
- Éviter les éléments personnels (barre des tâches Windows)
- Utiliser le mode clair OU sombre (cohérence)

### Post-traitement (optionnel)
Si vous souhaitez améliorer les screenshots :

```powershell
# Redimensionner avec ImageMagick
magick convert 01_timeline.png -resize 50% 01_timeline_small.png

# Ajouter un cadre arrondi (optionnel)
magick convert 01_timeline.png -alpha set -background none `
  -vignette 0x20 -fuzz 50% -trim +repage 01_timeline_rounded.png
```

---

## 🔄 Workflow Complet

### Capture Initiale (Une fois)
```powershell
# 1. Créer le dossier
New-Item -ItemType Directory -Path "docs\screenshots" -Force

# 2. Lancer l'app
flutter run -d windows

# 3. Capturer manuellement les 5 screenshots
# (suivre la checklist ci-dessus)

# 4. Renommer les fichiers
01_timeline.png
02_meal_composer.png
03_insights.png
04_calendar.png
05_settings.png
```

### Mise à jour (Après changements UI)
```powershell
# Recapturer uniquement les pages modifiées
# Exemple: Si insights_page a changé
flutter run -d windows
# → Naviguer vers Insights
# → Capturer 03_insights.png
```

---

## 🎨 Intégration dans README

Une fois capturés, les screenshots sont référencés dans `README.md` :

```markdown
## 📸 Screenshots

<div align="center">
  <img src="docs/screenshots/01_timeline.png" width="30%" alt="Timeline"/>
  <img src="docs/screenshots/02_meal_composer.png" width="30%" alt="Meal Composer"/>
  <img src="docs/screenshots/03_insights.png" width="30%" alt="Insights"/>
</div>

<div align="center">
  <img src="docs/screenshots/04_calendar.png" width="45%" alt="Calendar"/>
  <img src="docs/screenshots/05_settings.png" width="45%" alt="Settings"/>
</div>
```

---

## ❓ Troubleshooting

### Problème : integration_test échoue sur Android
**Solution** : Vérifiez que l'émulateur est bien démarré
```bash
flutter devices
adb devices
```

### Problème : Screenshots vides ou noirs
**Solution** : Ajoutez un délai supplémentaire dans le test
```dart
await Future.delayed(const Duration(seconds: 3));
await tester.pumpAndSettle();
```

### Problème : Fenêtre trop grande/petite sur Windows
**Solution** : Redimensionnez manuellement la fenêtre à 1280x720 avant de capturer

---

## 📝 Checklist Finale

Avant de commiter les screenshots :

- [ ] Les 5 screenshots sont capturés
- [ ] Format PNG (pas JPG)
- [ ] Résolution cohérente
- [ ] Noms corrects (`01_*.png`, `02_*.png`, etc.)
- [ ] Pas d'éléments personnels visibles
- [ ] Thème cohérent (tout en light OU tout en dark)
- [ ] Sauvegardés dans `docs/screenshots/`
- [ ] Référencés dans README.md

---

**✅ Une fois terminé, committez :**

```bash
git add docs/screenshots/*.png
git add README.md
git commit -m "docs: Add application screenshots for README"
```
