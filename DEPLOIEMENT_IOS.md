# Guide de Déploiement iOS - Crohnicles

Ce guide vous accompagne dans le processus complet pour tester Crohnicles sur votre appareil iOS physique ou le déployer sur l'App Store.

---

## Prérequis

### Matériel & Logiciels
- **Mac** avec macOS 12+ (Monterey ou supérieur)
- **Xcode 15+** installé depuis Mac App Store
- **Apple Developer Account** :
  - Gratuit : Pour tests sur appareil personnel uniquement (certificat expire après 7 jours)
  - Payant (99$/an) : Pour distribution TestFlight et App Store
- **Appareil iOS 13+** avec câble USB-C ou Lightning
- **Flutter SDK** déjà installé (vérifier : `flutter doctor`)

### Vérification Préalable
```bash
# Depuis le dossier du projet Crohnicles
flutter doctor -v

# Vous devez voir :
# [✓] Xcode - develop for iOS and macOS
# [✓] Connected device (iPhone/iPad si branché)
```

---

## Étape 1 : Configuration du Bundle Identifier & Équipe

### 1.1 Ouvrir le projet dans Xcode
```bash
cd /chemin/vers/crohnicles
open ios/Runner.xcworkspace  # ⚠️ Utilisez .xcworkspace, PAS .xcodeproj
```

### 1.2 Configurer le Bundle ID
1. Dans Xcode, sélectionnez **Runner** dans le navigateur de projet (panneau gauche)
2. Cliquez sur l'onglet **Signing & Capabilities**
3. Sous **Bundle Identifier**, remplacez `com.example.crohnicles` par votre ID unique :
   ```
   com.VOTRENOM.crohnicles
   # Exemple : com.jean-dupont.crohnicles
   ```
   > **Important** : Utilisez uniquement des lettres minuscules, chiffres, et tirets. Pas d'espaces ou caractères spéciaux.

### 1.3 Configurer la Signature (Signing)
1. Toujours dans **Signing & Capabilities**
2. Cochez **"Automatically manage signing"**
3. Dans **Team**, sélectionnez :
   - **Personal Team** (gratuit) : Apparaît comme "Votre Nom (Personal Team)"
   - **Developer Team** (payant) : Si vous avez un compte développeur

> **Note** : Avec Personal Team, les apps expirent après 7 jours. Vous devrez rebuilder pour continuer à utiliser l'app.

### 1.4 Résoudre les Conflits de Bundle ID
Si Xcode affiche "Failed to register bundle identifier", c'est que votre ID est déjà pris. Ajoutez un suffixe :
```
com.votrenom.crohnicles.perso
```

---

## Étape 2 : Configuration des Permissions (Privacy)

iOS 17+ exige des descriptions explicites pour toutes les permissions.

### 2.1 Éditer Info.plist
```bash
open ios/Runner/Info.plist  # Ouvre dans Xcode
```

### 2.2 Ajouter les Clés Manquantes
Ajoutez ces lignes dans le fichier `Info.plist` :

```xml
<key>NSCameraUsageDescription</key>
<string>Crohnicles utilise l'appareil photo pour scanner les codes-barres des produits alimentaires</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Crohnicles peut accéder à vos photos pour les associer à vos repas</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>Crohnicles utilise votre localisation pour obtenir la météo locale et corréler avec vos symptômes</string>
```

### 2.3 Configurer App Transport Security (Optionnel)
Si vous utilisez des APIs non-HTTPS (non recommandé), ajoutez :
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>world.openfoodfacts.org</key>
        <dict>
            <key>NSTemporaryExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

---

## Étape 3 : Vérification du Modèle ML

Crohnicles utilise TensorFlow Lite pour les prédictions. Vérifiez que les modèles sont bien inclus.

### 3.1 Ajouter les Modèles aux Ressources iOS
1. Dans Xcode, clic droit sur **Runner** → **Add Files to "Runner"**
2. Naviguez vers `assets/models/`
3. Sélectionnez TOUS les fichiers `.json` et `.tflite`
4. Cochez :
   - ✅ **Copy items if needed**
   - ✅ **Create folder references**
   - ✅ **Add to targets: Runner**

### 3.2 Tester la Compilation
```bash
flutter build ios --debug --no-codesign

# Si erreur TFLite :
# - Vérifiez pubspec.yaml contient : tflite_flutter: ^0.10.0
# - Exécutez : flutter pub get
```

---

## Étape 4 : Déploiement sur Appareil (Test)

### 4.1 Connecter votre iPhone/iPad
1. Branchez l'appareil via câble USB
2. Déverrouillez l'appareil
3. Si popup "Faire confiance à cet ordinateur" → **Faire confiance**

### 4.2 Option A : Via Xcode (Interface Graphique)
1. Dans Xcode, en haut, sélectionnez votre appareil (ex: "iPhone 15 Pro")
2. Cliquez sur **Product** → **Run** (ou `Cmd+R`)
3. Attendez la compilation (1-3 minutes)
4. **SUR VOTRE iPhone** : 
   - Allez dans **Réglages** → **Général** → **VPN et gestion des périphériques**
   - Cliquez sur votre certificat développeur
   - **"Faire confiance à..."**
5. Relancez l'app depuis l'écran d'accueil iOS

### 4.3 Option B : Via Flutter CLI (Plus Rapide)
```bash
# 1. Lister les appareils connectés
flutter devices

# Output exemple :
# iPhone 15 Pro (00008120-001234567890XXXX) • ios • iOS 17.2

# 2. Installer sur l'appareil
flutter run -d 00008120-001234567890XXXX

# Ou simplement (si un seul appareil) :
flutter run
```

> **Astuce** : Pour activer le Hot Reload, tapez `r` dans le terminal après modifications de code.

---

## Étape 5 : Debugging Courant

### Problème 1 : "Development team not configured"
**Solution** :
1. Ouvrez `ios/Runner.xcworkspace` dans Xcode
2. Sélectionnez Runner → Signing & Capabilities
3. Choisissez votre équipe dans le dropdown "Team"

### Problème 2 : "Failed to verify bitcode"
**Solution** :
```bash
# Dans Xcode :
# Runner → Build Settings → Recherchez "Bitcode"
# Enable Bitcode → NO
```

### Problème 3 : "Unable to install .app"
**Causes fréquentes** :
- Version iOS trop ancienne (<13.0) → Mettez à jour l'iPhone
- Espace disque insuffisant → Libérez de l'espace
- Certificat expiré (Personal Team après 7 jours) → Recompilez

**Solution** :
```bash
flutter clean
flutter pub get
flutter run
```

### Problème 4 : TFLite Model Not Loading
**Solution** :
1. Vérifiez que `assets/models/*.tflite` sont dans Xcode (voir Étape 3.1)
2. Ajoutez dans `ios/Runner/Info.plist` :
```xml
<key>FLTEnableDartObfuscation</key>
<false/>
```

### Problème 5 : SQLite Performance Lente
**Solution** : Crohnicles utilise `sqflite_common_ffi` optimisé iOS. Si lenteurs :
```dart
// Dans database_helper.dart, augmentez le pool de connexions :
await db.execute('PRAGMA journal_mode = WAL');
await db.execute('PRAGMA synchronous = NORMAL');
```

---

## Étape 6 : Distribution TestFlight (Beta Testing)

### 6.1 Prérequis
- **Apple Developer Program** payant (99$/an)
- Compte configuré sur [App Store Connect](https://appstoreconnect.apple.com/)

### 6.2 Créer l'Archive
```bash
# 1. Build en mode Release
flutter build ipa --release

# 2. L'archive est dans : build/ios/archive/Runner.xcarchive
```

### 6.3 Upload vers App Store Connect
**Option A : Via Xcode Organizer**
1. Ouvrez `ios/Runner.xcworkspace` dans Xcode
2. **Product** → **Archive** (attendez 5-10 min)
3. Window → **Organizer**
4. Sélectionnez votre archive → **Distribute App**
5. Choisissez **App Store Connect** → **Upload**
6. Suivez l'assistant (laisser options par défaut)

**Option B : Via Transporter.app**
1. Téléchargez **Transporter** depuis Mac App Store
2. Glissez-déposez le fichier `.ipa` (dans `build/ios/ipa/`)
3. Cliquez **Deliver**

### 6.4 Inviter des Testeurs
1. Allez sur [App Store Connect](https://appstoreconnect.apple.com/)
2. **My Apps** → **Crohnicles** → **TestFlight**
3. Sélectionnez la version uploadée
4. **Testeurs internes** : Ajoutez jusqu'à 100 testeurs (membres de votre équipe dev)
5. **Testeurs externes** : Ajoutez jusqu'à 10,000 testeurs (nécessite revue Apple, 24-48h)

### 6.5 Délai de Revue Apple
- **Testeurs internes** : Instantané (dès upload terminé)
- **Testeurs externes** : 24-72h de revue par Apple

---

## Étape 7 : Publication App Store (Production)

### 7.1 Préparer les Assets
1. **Icône App** (1024×1024 px) :
   - PNG sans transparence
   - Placer dans `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

2. **Screenshots** (Requis pour au moins iPhone 6.7" et iPad Pro) :
   - Utilisez Simulator pour capturer : `Cmd+S`
   - Tailles requises : Voir [Apple Guidelines](https://help.apple.com/app-store-connect/#/devd274dd925)

### 7.2 Créer la Fiche App Store
1. [App Store Connect](https://appstoreconnect.apple.com/) → **My Apps** → **+** → **New App**
2. Remplissez :
   - **Name** : Crohnicles
   - **Primary Language** : French
   - **Bundle ID** : Sélectionnez votre `com.xxx.crohnicles`
   - **SKU** : `crohnicles-001` (identifiant interne unique)

3. **App Information** :
   - **Category** : Medical (catégorie principale) + Health & Fitness (secondaire)
   - **Description** : (max 4000 caractères)
     ```
     Crohnicles est votre compagnon personnel pour le suivi des maladies inflammatoires chroniques de l'intestin (MICI) : Maladie de Crohn et Rectocolite Hémorragique.

     🔍 FONCTIONNALITÉS PRINCIPALES :
     • Suivi quotidien : repas, symptômes, selles (échelle de Bristol)
     • Analyse des déclencheurs alimentaires avec corrélations temporelles
     • Corrélations météorologiques (température, humidité, pression)
     • Prédictions ML pour anticiper les crises
     • Timeline visuelle avec liens repas→symptômes
     • Export PDF médecin avec méthodologie détaillée

     📊 ANALYSE INTELLIGENTE :
     Crohnicles utilise l'intelligence artificielle pour identifier vos déclencheurs personnels et corréler vos symptômes avec l'alimentation et la météo.

     🔒 VIE PRIVÉE :
     Vos données restent sur votre appareil. Aucune synchronisation cloud. Vous êtes propriétaire de vos informations médicales.

     ⚠️ AVERTISSEMENT MÉDICAL :
     Crohnicles est un outil de suivi, PAS un dispositif médical. Consultez toujours votre gastro-entérologue pour les décisions thérapeutiques.
     ```

4. **Pricing & Availability** :
   - Prix : Free (gratuit recommandé pour app santé)
   - Disponibilité : Tous les pays (ou sélection manuelle)

### 7.3 Soumettre pour Revue
1. Uploadez le build via Xcode/Transporter (voir Étape 6.2)
2. Dans App Store Connect, associez le build à la version
3. **App Review Information** :
   - **Notes pour le reviewer** :
     ```
     Compte de test démo :
     - Les données de démonstration se génèrent automatiquement au premier lancement
     - Naviguez vers l'onglet "Analyses" pour voir les graphiques
     - Utilisez l'onglet "Timeline" pour visualiser les corrélations
     
     L'app utilise :
     - Localisation pour météo (optionnelle)
     - Appareil photo pour scan code-barres OpenFoodFacts
     - Photos pour attacher des images aux repas
     ```

4. Cochez **"Export Compliance"** :
   - "Does your app use encryption?" → **NO** (sauf si vous implémentez HTTPS avec certificats custom)

5. **Submit for Review**

### 7.4 Délai de Revue
- Première soumission : 2-7 jours
- Mises à jour : 1-3 jours
- Rejets courants :
  - Screenshots ne correspondent pas à l'app
  - Crash au lancement
  - Demande de permissions non justifiées

---

## Étape 8 : Maintenance & Mises à Jour

### 8.1 Cycle de Vie d'une Update
```bash
# 1. Modifier le code
# 2. Incrémenter version dans pubspec.yaml :
version: 1.0.1+2  # Format: <version>+<build_number>

# 3. Build
flutter build ipa --release

# 4. Upload vers TestFlight pour beta test

# 5. Si OK, soumettre à l'App Store
```

### 8.2 Versioning Sémantique
- **Major** (1.x.x) : Changements incompatibles (ex: nouvelle DB schema)
- **Minor** (x.1.x) : Nouvelles fonctionnalités compatibles
- **Patch** (x.x.1) : Corrections de bugs

### 8.3 Gestion des Certificats
- **Certificats de développement** : Expirent après 1 an
- **Certificats de distribution** : Expirent après 1 an
- Xcode renouvelle automatiquement si "Automatically manage signing" est activé

---

## Troubleshooting Avancé

### Logs en Temps Réel
```bash
# Voir les logs de l'app sur iPhone connecté :
flutter logs

# Ou via Console.app (Mac) :
# 1. Ouvrez Console.app
# 2. Sélectionnez votre iPhone dans la sidebar
# 3. Filtrez par "Crohnicles"
```

### Réinitialiser Tous les Certificats
```bash
# Dans Xcode :
# Preferences → Accounts → Sélectionnez votre compte
# Clic-droit → "Manage Certificates..." → Revoke All

# Puis :
rm -rf ~/Library/Developer/Xcode/DerivedData/*
flutter clean
```

### Performance Profiling
```bash
# Lancer en mode profile :
flutter run --profile -d <device_id>

# Ouvrir DevTools :
flutter pub global run devtools
```

---

## Ressources Officielles

- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Flutter iOS Deployment](https://docs.flutter.dev/deployment/ios)
- [TestFlight Guide](https://developer.apple.com/testflight/)

---

## Support

Pour toute question sur le déploiement iOS de Crohnicles :
1. Vérifiez d'abord [flutter doctor issues](https://docs.flutter.dev/get-started/install/macos#run-flutter-doctor)
2. Consultez [GitHub Issues](https://github.com/votre-repo/crohnicles/issues)
3. Référez-vous aux logs : `flutter logs > debug.log`

---

**Bon déploiement ! 🚀**
