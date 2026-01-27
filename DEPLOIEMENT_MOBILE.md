# Déploiement Mobile - Détection Photo Aliments

## 🎯 Fonctionnalités IA (Mobile uniquement)

### 1. Détection Code-Barres Automatique
- **Package**: `google_mlkit_barcode_scanning`
- **Formats**: EAN-8, EAN-13
- **Plateformes**: ✅ Android, ✅ iOS | ❌ Windows/Desktop

### 2. Reconnaissance Aliments (TensorFlow Lite)
- **Modèle**: Food-101 MobileNetV2 (101 classes)
- **Taille**: ~15 MB inclus dans l'APK
- **Plateformes**: ✅ Android, ✅ iOS | ❌ Windows (DLL manquante)

## 📱 Build Android

### Prérequis
```bash
# Vérifier configuration Android
flutter doctor -v

# Si Android SDK manquant:
# - Télécharger Android Studio: https://developer.android.com/studio
# - Ouvrir Android Studio → SDK Manager → Install Android SDK
# - flutter config --android-sdk C:\Users\[USER]\AppData\Local\Android\Sdk
```

### Build APK de Test
```bash
# APK Debug (développement)
flutter build apk --debug

# APK Release (production)
flutter build apk --release

# Fichier généré:
# build/app/outputs/flutter-apk/app-release.apk
```

### Installation sur Téléphone Android
```bash
# Via USB debugging (activer "Options développeur" sur téléphone)
flutter install

# Ou manuellement:
# - Copier app-release.apk sur téléphone
# - Installer depuis "Fichiers" (autoriser sources inconnues)
```

## 🧪 Test sur Émulateur Android

### Créer Émulateur (si Android SDK installé)
```bash
# Lister émulateurs disponibles
flutter emulators

# Si vide, créer depuis Android Studio:
# Tools → AVD Manager → Create Virtual Device
# - Device: Pixel 5 ou plus récent
# - System Image: Android 13 (API 33) ou supérieur
# - RAM: 2048 MB minimum

# Lancer émulateur
flutter emulators --launch <emulator_id>

# Lancer app
flutter run -d emulator-5554
```

### Test Workflow Complet
1. **Upload Galerie**:
   - Préparer images avec code-barres produits (Coca-Cola, Nutella...)
   - Drag & drop images dans émulateur
   - Ouvrir app → Menu Repas → Onglet "Scanner" → "Galerie"

2. **Détection Barcode**:
   - Sélectionner image
   - Vérifier logs: `[BarcodeDetection] Detected: <code>`
   - Produit ajouté automatiquement au panier

3. **Reconnaissance Aliments** (si pas de barcode):
   - Upload photo de plat (pizza, burger, salade...)
   - Vérifier logs: `[FoodRecognizer] Inference completed in Xms`
   - Dialog avec top-3 prédictions
   - Sélectionner aliment → ajouté au panier

## 📊 Codes-Barres de Test

### Produits Courants
- **Coca-Cola**: `5449000000996`
- **Coca-Cola Zero**: `5449000000897`
- **Nutella**: `3017620422003`
- **Kinder Bueno**: `8000500310427`
- **Orangina**: `3124480159878`

### Générer Images Test
Télécharger images avec barcodes:
- https://www.barcodesinc.com/generator/ (générateur en ligne)
- Ou scanner produits réels avec téléphone

## 🍔 Classes Aliments Reconnues (101)

<details>
<summary>Voir la liste complète</summary>

```
Desserts: apple pie, baklava, carrot cake, cheesecake, chocolate cake, 
          chocolate mousse, churros, creme brulee, cup cakes, donuts,
          ice cream, macarons, panna cotta, tiramisu, waffles...

Plats: pizza, hamburger, hot dog, sushi, spaghetti bolognese, 
       spaghetti carbonara, pad thai, paella, ramen, tacos...

Viandes: chicken curry, chicken wings, filet mignon, grilled salmon,
         peking duck, pork chop, prime rib, steak...

Salades: caesar salad, caprese salad, greek salad, seaweed salad...

Et 70+ autres classes (voir assets/models/food_labels.txt)
```
</details>

## ⚙️ Configuration Permissions

### Android (android/app/src/main/AndroidManifest.xml)
Déjà configuré:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.INTERNET" />
```

### iOS (ios/Runner/Info.plist)
Déjà configuré:
```xml
<key>NSCameraUsageDescription</key>
<string>Crohnicles needs camera access to scan product barcodes</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Crohnicles needs photo access to identify food from images</string>
```

## 🐛 Troubleshooting

### Problème: "MissingPluginException google_mlkit_barcode_scanning"
**Cause**: Plugin non compilé pour la plateforme actuelle
**Solution**:
```bash
flutter clean
flutter pub get
flutter run -d <android_device>
```

### Problème: "Failed to load TFLite model"
**Cause**: Modèle `food_classifier.tflite` manquant dans `assets/models/`
**Solution**:
```bash
# Vérifier présence du fichier
ls assets/models/food_classifier.tflite

# Si manquant, replacer le fichier .tflite téléchargé
```

### Problème: "Permission denied" Camera/Gallery
**Cause**: Permissions non accordées sur l'appareil
**Solution**:
- Android: Settings → Apps → Crohnicles → Permissions → Camera/Storage
- iOS: Settings → Privacy → Camera/Photos → Crohnicles

### Problème: Windows DLL Error (développement)
**Normal**: TFLite et ML Kit ne fonctionnent pas sur Windows
**Workflow**: Upload galerie → Dialog manuel (comme avant)
**Test complet**: Utiliser émulateur/appareil Android

## 📈 Performances

### Temps de Traitement (Android mid-range)
- **Barcode Detection**: 100-300ms
- **Food Recognition**: 300-800ms
- **Total Workflow**: ~1-2s (incluant OpenFoodFacts API)

### Taille App
- **Base App**: ~30 MB
- **+ Food-101 Model**: ~15 MB
- **+ ML Kit**: ~3 MB (Google Play Services) ou ~600 KB (unbundled)
- **Total**: ~45-50 MB

### Utilisation Hors Ligne
- ✅ Barcode detection: Fonctionne offline
- ✅ Food recognition: Fonctionne offline
- ❌ OpenFoodFacts lookup: Nécessite Internet

## 🚀 Déploiement Production

### Google Play Store (App Bundle recommandé)
```bash
# Build App Bundle (format Google Play)
flutter build appbundle --release

# Fichier: build/app/outputs/bundle/release/app-release.aab
```

### Signature APK (si non configurée)
```bash
# Générer keystore (1ère fois uniquement)
keytool -genkey -v -keystore crohnicles-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias crohnicles

# Configurer dans android/key.properties:
storePassword=<password>
keyPassword=<password>
keyAlias=crohnicles
storeFile=../../crohnicles-key.jks
```

### iOS App Store
```bash
# Build IPA
flutter build ipa --release

# Nécessite:
# - Apple Developer Account ($99/an)
# - Xcode sur macOS
# - Certificats de signature configurés
```

## 📚 Ressources

- **ML Kit Barcode**: https://developers.google.com/ml-kit/vision/barcode-scanning
- **TensorFlow Lite**: https://www.tensorflow.org/lite
- **Food-101 Dataset**: https://www.kaggle.com/datasets/dansbecker/food-101
- **Flutter Build Modes**: https://docs.flutter.dev/testing/build-modes

---

**Note**: Les fonctionnalités IA (barcode + food recognition) sont 100% locales et gratuites. Pas de coûts API cachés.
