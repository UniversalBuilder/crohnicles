# 🩺 Crohnicles

> **Journal intelligent de santé pour les maladies inflammatoires chroniques de l'intestin (MICI)**

Crohnicles est une application mobile et desktop de suivi personnel pour les personnes atteintes de la **maladie de Crohn** ou de **rectocolite hémorragique (RCH)**. Elle permet d'enregistrer repas, symptômes et selles, puis utilise l'**analyse statistique locale** pour identifier des corrélations personnalisées entre alimentation et symptômes.

[![Flutter](https://img.shields.io/badge/Flutter-3.10.7-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-blue)](LICENSE.md)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Windows%20%7C%20Web-lightgrey)]()

---

## 📋 Table des matières

- [Pourquoi Crohnicles ?](#-pourquoi-crohnicles-)
- [Fonctionnalités principales](#-fonctionnalités-principales)
- [Comment ça marche ?](#-comment-ça-marche-)
- [Architecture & Technologies](#-architecture--technologies)
- [Installation](#-installation)
- [Utilisation](#-utilisation)
- [Confidentialité & Sécurité](#-confidentialité--sécurité)
- [Contribuer](#-contribuer)
- [Auteur & License](#-auteur--license)
- [Avertissement Médical](#-avertissement-médical)

---

## 🎯 Pourquoi Crohnicles ?

Vivre avec une MICI, c'est souvent jongler entre :
- 🍽️ **Repas** : Qu'ai-je mangé ? Quels ingrédients ?
- 😣 **Symptômes** : Douleurs, ballonnements, fatigue...
- 🚽 **Selles** : Type Bristol, fréquence, sang...
- 🧪 **Traitements** : Observance médicamenteuse
- 📊 **Corrélations** : Quel aliment déclenche mes crises ?

Les applications généralistes de santé sont trop complexes ou inadaptées. Les carnets papier sont fastidieux et n'offrent aucune analyse.

**Crohnicles résout ces problèmes** en offrant :
1. ✅ **Saisie ultra-rapide** (base OpenFoodFacts, tags intelligents)
2. ✅ **Analyse statistique personnalisée** (corrélations Aliment → Symptôme)
3. ✅ **Confidentialité totale** (données stockées localement, aucune fuite)
4. ✅ **Interface moderne** (Material Design 3, glassmorphism, dark mode)
5. ✅ **Multiplateforme** (Android, iOS, Windows, macOS, Linux, Web)

---

## ✨ Fonctionnalités principales

### 🔒 Sécurité & Confidentialité
- **Chiffrement base de données** : AES-256 SQLCipher activable dans Settings
- **Validation des saisies** : Contrôles stricts (dates, quantités, échelles médicales)
- **Export RGPD** : Export CSV complet de toutes vos données (UTF-8 BOM Excel-compatible)
- **Suppression définitive** : Droit à l'oubli RGPD (suppression base + clé de chiffrement)
- **Stockage local** : Aucune fuite de données vers serveurs externes
- **API Keys sécurisées** : Gestion via .env (jamais hardcodées)

### 🍴 Gestion des Repas
- **Compositeur intelligent** : 4 onglets (🥖 Pain, 🥩 Protéines, 🥗 Légumes, 🥤 Boissons)
- **Intégration OpenFoodFacts** : Scan de code-barres + base de données de 2M+ produits
- **Autocomplétion** : Base locale des aliments personnels
- **Tags flexibles** : Gluten, Lactose, Épices, etc.
- **Calcul nutritionnel** : Calories, glucides, lipides, protéines (automatique si produit OpenFF)
- **Groupement temporel** : Événements proches regroupés sur timeline (amélioration lisibilité)

### 🩹 Suivi des Symptômes
- **Wizard 3 étapes** : Navigation fluide (Sélection → Intensités → Résumé)
  - **Étape 1** : Drill-down interactif par zone (Abdomen → Quadrant supérieur droit → Douleur aiguë)
  - **Étape 2** : Sliders d'intensité pour chaque symptôme sélectionné
  - **Étape 3** : Récapitulatif avec silhouette abdominale (si douleurs localisées)
- **Taxonomie médicale** : 5 niveaux hiérarchiques (Système → Catégorie → Zone → Type → Détail)
- **Contexte automatique** : Météo, humeur, stress (via background service)
- **Analyse interactive** : Click sur graphique → déclencheurs identifiés avec transparence totale (5 infos obligatoires)

### 💩 Journal de Selles (Bristol Stool Scale)
- Types 1-7 avec illustrations
- Urgence, fréquence, présence de sang/mucus
- Corrélations avec repas précédents

### 📊 Insights & Prédictions
- **Analyse statistique** : P(Symptôme | Aliment) sur fenêtre de 4-8h
- **Seuils de confiance** : Minimum 10 échantillons pour haute fiabilité
- **Mode temps réel** : Analyse des 10 repas similaires (démarrage avec peu de données)
- **Entraînement du modèle** : À partir de 30 repas + 30 symptômes sévères (≥5)
- **Statut ML en temps réel** : Card affichant progression (X/30 repas, X/30 symptômes)
- **Graphiques interactifs** : Timeline, PieCharts, BarCharts (fl_chart)

### 🔧 Paramètres & Maintenance
- **Thème** : Light/Dark mode (système ou manuel)
- **Chiffrement** : Toggle activation/désactivation avec migration automatique
- **Export RGPD** : CSV complet de toutes vos données (partage mobile/desktop)
- **Suppression RGPD** : Droit à l'oubli (suppression définitive DB + clés)
- **Logs** : Debug sur appareil (pour support)
- **TimePicker** : Format 24h automatique selon paramètres système

---

## 🧠 Comment ça marche ?

### 1. **Collecte de Données**
Vous enregistrez vos repas, symptômes et selles au quotidien. Crohnicles stocke tout dans une base SQLite locale avec :
- `events` table : Log central (type: meal/symptom/stool/checkup)
- `meta_data` JSON : Données flexibles (aliments, tags, météo)
- `context_data` : Informations contextuelles (géolocalisation, humeur)

### 2. **Analyse Statistique (Phase 1)**
L'app calcule des **corrélations bayésiennes** :
```
P(Symptôme | Aliment) = Nb de symptômes après aliment / Nb total d'occurrences aliment
Confiance = min(1.0, Nb échantillons / 10)
```

**Exemple concret** :
- Vous avez mangé 12 fois du gluten
- 7 fois → douleur dans les 8h suivantes
- **Résultat** : Gluten = 58% de risque (confiance 100%)

### 3. **Mode Temps Réel (Démarrage)**
Si vous avez <30 repas, l'app utilise un mode conservatif :
- Recherche les 10 repas les plus similaires (tags communs)
- Calcule le taux de symptômes sur ces 10 échantillons
- Confiance limitée à 30% maximum

### 4. **Entraînement du Modèle (Phase 2)**
Après 30 repas + 20 symptômes, vous pouvez entraîner le modèle statistique :
- Recalcul de toutes les corrélations significatives (>10% probabilité, >30% confiance)
- Stockage dans une structure optimisée
- Prédictions instantanées pour les nouveaux repas

### 5. **Prédiction en Temps Réel**
Quand vous saisissez un nouveau repas, Crohnicles :
1. Extrait les features (aliments, tags, quantités, heure)
2. Interroge le modèle statistique
3. Affiche un **Risk Assessment Card** avec :
   - Score de risque global (0-100%)
   - Déclencheurs identifiés par catégorie (Douleur, Ballonnement, etc.)
   - Confiance de la prédiction

---

## 🏗️ Architecture & Technologies

### Stack Technique
- **Frontend** : Flutter 3.38.7 (Dart 3.10.7)
- **UI Framework** : Material Design 3 (themes modulaires, WCAG AA)
- **State Management** : Provider
- **Database** : SQLite (sqflite) + **Encryption AES-256** (sqlcipher_flutter_libs)
- **Machine Learning** : TensorFlow Lite (prédictions on-device, aucun serveur)
- **Charts** : fl_chart (graphiques interactifs)
- **APIs** : OpenFoodFacts (cache local 90 jours)
- **Background Services** : Workmanager (météo automatique toutes les 6h)
- **Security** : 
  - flutter_dotenv (gestion secrets, API keys dans .env)
  - flutter_secure_storage (stockage clés de chiffrement)
  - sqlcipher_flutter_libs (chiffrement base de données)
- **Export** : share_plus (partage multi-plateforme), intl (formatage dates)

### Architecture Logicielle
```
lib/
├── themes/           # Design System MD3 (5 fichiers)
│   ├── app_theme.dart
│   ├── color_schemes.dart
│   ├── text_themes.dart
│   ├── app_gradients.dart
│   └── chart_colors.dart
├── models/           # Data Models (EventModel, FoodModel, etc.)
├── services/         # Business Logic (DB, ML, Context, Logs)
│   ├── database_helper.dart
│   ├── context_service.dart (OpenWeather API)
│   ├── off_service.dart (OpenFoodFacts)
│   └── log_service.dart
├── ml/               # Machine Learning (ModelManager, FeatureExtractor, StatisticalEngine)
├── providers/        # State Management (ThemeProvider, etc.)
├── utils/            # Helpers (ResponsiveWrapper, DateUtils, PlatformUtils)
└── *.dart            # Pages (main, calendar, insights, timeline, etc.)

docs/
├── CALCULATIONS.md   # Formules, seuils, règles de transparence
└── SCREENSHOTS.md    # Guide visuel de l'app

.env                  # Secrets (API keys, non versionné)
.env.example          # Template pour développeurs
```

### Clean Architecture
- **Data Layer** : `DatabaseHelper` (singleton thread-safe avec Completer)
- **Domain Layer** : Models + Business logic (risk scoring, correlation analysis)
- **Presentation Layer** : Pages + Dialogs (Material widgets)

### Règles Critiques
1. **Schema Migrations** : Incrémentation `_version` + gestion `_onUpgrade`
2. **JSON Flexibility** : `meta_data` toujours wrappé dans un objet
3. **Dates** : Format ISO8601 strict (`YYYY-MM-DDTHH:MM:SS`)
4. **ML Parity** : Features Dart ↔ Python identiques (ordre + noms)

---

## 🚀 Installation

### Prérequis
- **Flutter SDK 3.10.7+** ([Installation](https://docs.flutter.dev/get-started/install))
- **Pour Android** : Android Studio + Android SDK 24+ (Android 7.0)
- **Pour iOS** : Xcode 13+ + CocoaPods (macOS uniquement)
- **Pour Windows** (optionnel) : Visual Studio 2022
- Git

### Étapes

1. **Cloner le dépôt**
```bash
git clone https://github.com/YOUR_USERNAME/crohnicles.git
cd crohnicles
```

2. **Installer les dépendances**
```bash
flutter pub get
```

3. **Configuration des variables d'environnement**

Créez un fichier `.env` à la racine du projet (copier depuis `.env.example`) :
```bash
# Windows
copy .env.example .env

# macOS/Linux
cp .env.example .env
```

Éditez `.env` et ajoutez votre clé API OpenWeather (optionnel, pour contexte météo) :
```env
OPENWEATHER_API_KEY=your_api_key_here
```

> **Note:** Le fichier `.env` est dans `.gitignore` et ne sera jamais versionné. Si vous ne fournissez pas de clé API, l'app fonctionnera normalement mais sans corrélations météorologiques.

4. **Lancer l'application**

**Android** (prioritaire) :
```bash
# Sur émulateur Android Studio
flutter emulators --launch <EMULATOR_ID>
flutter run

# Sur appareil physique (mode développeur activé + USB debugging)
flutter run
```

**iOS** (nécessite macOS) :
```bash
# Sur simulateur
open -a Simulator
flutter run

# Sur appareil physique (nécessite compte développeur Apple)
flutter run
```

**Windows** (pour développement rapide) :
```bash
flutter run -d windows
```

**Web** (expérimental) :
```bash
flutter run -d chrome
```

### Configuration OpenFoodFacts (optionnel)
Pour utiliser l'API OpenFoodFacts, créez un fichier `.env` :
```env
OPENFOODFACTS_USER_AGENT=Crohnicles/1.0.0
```

### Build de Production

**Android (APK)** :
```bash
# Debug APK (pour test)
flutter build apk --debug

# Release APK (pour distribution directe)
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

**Android (App Bundle - Google Play)** :
```bash
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab
```

**iOS (IPA)** :
```bash
# Nécessite un compte développeur Apple + certificat
flutter build ipa
```

---

## 📱 Utilisation

### 1. Premier Lancement
- Choisissez votre thème (Light/Dark)
- Activez les notifications (optionnel)
- Autorisez la géolocalisation (pour la météo)

### 2. Enregistrer un Repas
1. **Onglet Timeline** → Bouton `+` → **Repas**
2. **Scan** un code-barres OU **Recherche** manuelle
3. Ajoutez des tags (Gluten, Lactose, etc.)
4. Validez → **Risk Assessment** s'affiche automatiquement

### 3. Enregistrer un Symptôme
1. Bouton `+` → **Symptôme**
2. Drill-down : **Système** → **Catégorie** → **Zone** → **Type**
3. Intensité (1-10), début/fin, notes
4. Validez

### 4. Analyser les Insights
1. **Onglet Insights**
2. Graphiques : Timeline, PieChart (localisations), BarChart (fréquence)
3. **Click sur un graphique** → Drill-down sur les déclencheurs
4. Entraînez le modèle si ≥30 repas (bouton 🧠)

### 5. Exporter les Données
1. **Settings** → **Logs** → **Exporter**
2. Formats : CSV, JSON
3. Sauvegarde locale OU cloud (Google Drive)

---

## 🔒 Confidentialité & Sécurité

### Principes Fondamentaux
✅ **Aucune donnée ne quitte votre appareil** (sauf backup cloud optionnel)  
✅ **Aucun serveur tiers** : Tout est calculé localement  
✅ **Chiffrement AES-256** : Protection forte des données sensibles  
✅ **RGPD-compliant** : Droit à la portabilité et à l'oubli  
✅ **Open Source** : Code auditable publiquement  

### Fonctionnalités de Sécurité (v1.2)

#### 🔐 Chiffrement Base de Données
- **Algorithme** : AES-256 via SQLCipher
- **Activation** : Settings → "Chiffrer la base de données" (toggle)
- **Migration automatique** : Unencrypted ↔ Encrypted sans perte de données
- **Stockage clé** : flutter_secure_storage (Keychain iOS, Keystore Android)
- **Paramètres SQLCipher** :
  - PBKDF2_HMAC_SHA512 (256,000 itérations)
  - Page size : 4096 bytes
  - HMAC SHA512

**Protection contre :**
- ✅ Vol/perte d'appareil (données illisibles sans déverrouillage)
- ✅ Malware local (clé isolée dans secure storage)
- ⚠️ Ne protège PAS contre forensics avancé ou root/jailbreak

#### 📊 Export RGPD (Droit à la Portabilité)
- **Format** : CSV UTF-8 avec BOM (Excel-compatible)
- **Accès** : Settings → "Exporter mes données (CSV)"
- **Contenu** : Tous les événements (repas, symptômes, selles, bilans)
- **Structure** : Date, Type, Titre, Sévérité, Tags, Métadonnées
- **Partage** :
  - Mobile : Sheet système (Email, Drive, WhatsApp)
  - Desktop : Fichier dans Documents/
- **Conformité** : Article 20 RGPD (droit à la portabilité)

#### 🗑️ Suppression Définitive (Droit à l'Oubli)
- **Fonction** : Settings → "Supprimer toutes mes données"
- **Action** : Suppression irréversible :
  - Base de données principale
  - Fichiers temporaires (WAL, SHM)
  - Clé de chiffrement (secure storage)
  - Backups locaux
- **Conformité** : Article 17 RGPD (droit à l'oubli)

#### ✅ Validation des Saisies
- **Contrôles stricts** :
  - Dates : Max 2 ans d'ancienneté, pas de dates futures
  - Quantités : >0 et ≤2000g/ml
  - Sévérité : Échelle 1-10
  - Bristol Scale : Échelle 1-7
- **Feedback** : SnackBar rouge avec messages explicites
- **Objectif** : Garantir intégrité base de données

### Données Collectées
- **Repas** : Aliments, quantités, tags, timestamps
- **Symptômes** : Localisations anatomiques, intensités (1-10), types
- **Selles** : Types Bristol (1-7), fréquences, présence sang/mucus
- **Contexte** : Météo (si géolocalisation activée), notes libres
- **Aucune donnée personnelle identifiante** : Pas de nom, email, téléphone, adresse

### Intégrations Externes

#### OpenFoodFacts
- **Cache local** : 90 jours de rétention
- **Rate limiting** : Max 1 requête/200ms (respect ToS)
- **User-Agent** : Crohnicles/1.0.0 (déclaré)
- **Aucune donnée utilisateur envoyée** : Seuls codes-barres scannés

#### OpenWeather (Optionnel)
- **API Key** : Stockée dans `.env` (non versionnée)
- **Fréquence** : Background task toutes les 6h (si activé)
- **Données envoyées** : Coordonnées GPS uniquement
- **Stockage** : Contexte météo dans table events (meta_data JSON)

### Conformité RGPD

| Article | Description | Implémentation |
|---------|-------------|----------------|
| **Art. 6** | Consentement | ✅ Opt-in géolocalisation + météo |
| **Art. 17** | Droit à l'oubli | ✅ Suppression définitive + clé encryption |
| **Art. 20** | Portabilité | ✅ Export CSV complet |
| **Art. 32** | Sécurité | ✅ Chiffrement AES-256 + validation inputs |
| **Art. 33** | Notification breach | ✅ N/A (stockage local uniquement) |

### Audit & Transparence
- **Code source** : Disponible sur GitHub (licence CC BY-NC-SA 4.0)
- **Audit indépendant** : Bienvenu (ouvrir une issue pour coordination)
- **Formules statistiques** : Documentées dans [docs/CALCULATIONS.md](docs/CALCULATIONS.md)
- **Architecture** : Documentée dans [architecture_state.md](architecture_state.md)

---

## 🤝 Contribuer

Les contributions sont les bienvenues ! Voici comment :

### 1. Signaler un Bug
Ouvrez une [Issue](https://github.com/YOUR_USERNAME/crohnicles/issues) avec :
- Description du problème
- Étapes de reproduction
- Logs (Settings → Logs → Copier)

### 2. Proposer une Feature
Créez une [Discussion](https://github.com/YOUR_USERNAME/crohnicles/discussions) pour valider l'idée.

### 3. Soumettre une Pull Request
1. Fork le projet
2. Créez une branche (`git checkout -b feature/amazing-feature`)
3. Commitez (`git commit -m 'feat: Add amazing feature'`)
4. Pushez (`git push origin feature/amazing-feature`)
5. Ouvrez une PR avec description détaillée

### 4. Guidelines
- **Code Style** : Respectez le [Effective Dart](https://dart.dev/guides/language/effective-dart)
- **Tests** : Ajoutez des tests unitaires si applicable
- **Documentation** : Commentez le code complexe
- **Architecture** : Lisez `architecture_state.md` avant de modifier la DB

---

## 👨‍💻 Auteur & License

### Auteur
**Yannick KREMPP**  
📧 Email : [votre-email@example.com]  
🐦 Twitter : [@your_handle]  
💼 LinkedIn : [Votre Profil]

### Contexte du Projet
Crohnicles est un projet personnel créé pour gérer ma propre maladie de Crohn. L'objectif est de fournir un outil **gratuit, open source et respectueux de la vie privée** à la communauté des personnes atteintes de MICI.

### License
Ce projet est sous licence **Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0)**.

Vous êtes libre de :
- ✅ **Utiliser** l'application à des fins personnelles
- ✅ **Modifier** le code source
- ✅ **Redistribuer** vos modifications

**Conditions** :
- ⚠️ **Attribution** : Mentionnez "Crohnicles - Yannick KREMPP"
- 🚫 **Pas d'usage commercial** : Interdit de vendre l'app ou ses dérivés
- 🔄 **Partage identique** : Vos modifications doivent être sous la même licence

Voir [LICENSE.md](LICENSE.md) pour le texte complet.

### Soutenir le Projet
Si Crohnicles vous est utile, vous pouvez soutenir le développement :
- ⭐ **Star** le dépôt GitHub
- 💰 **Faire un don** (voir section "À propos" dans l'app)
- 📢 **Partager** avec d'autres personnes atteintes de MICI
- 🐛 **Signaler des bugs** ou proposer des features

---

## ⚠️ Avertissement Médical

**CROHNICLES N'EST PAS UN DISPOSITIF MÉDICAL CERTIFIÉ.**

- ❌ **Ne jamais** modifier un traitement médical sur la base des prédictions
- ❌ **Ne jamais** remplacer l'avis d'un gastro-entérologue
- ✅ **Toujours consulter** un professionnel de santé pour les décisions médicales

Les corrélations statistiques sont **personnelles et non généralisables**. Ce qui fonctionne pour vous peut ne pas fonctionner pour d'autres.

**L'auteur décline toute responsabilité** en cas d'usage inapproprié de l'application à des fins médicales.

---

## 📊 Statistiques du Projet

- **Lignes de code** : ~18,000
- **Fichiers** : 55+ (Dart)
- **Tests** : 26 tests d'accessibilité (WCAG AA compliance)
- **Langues** : Français (EN coming soon)
- **Plateformes** : Android, iOS, Windows, macOS, Linux, Web
- **Version actuelle** : v1.2 (Février 2026)

---

## 🗺️ Roadmap

### ✅ v1.1 (Janvier 2026) - Complété
- [x] Wizard symptômes 3 étapes (navigation progressive)
- [x] Silhouette abdomen avec zones interactives
- [x] Regroupement événements timeline
- [x] Corrections mode sombre
- [x] Sécurisation API OpenWeather (.env)

### ✅ v1.2 (Février 2026) - Complété
- [x] Chiffrement base de données AES-256 (SQLCipher)
- [x] Validation stricte des saisies (dates, quantités, échelles)
- [x] Export CSV RGPD-compliant (portabilité Article 20)
- [x] Suppression définitive RGPD (droit à l'oubli Article 17)
- [x] ML Training Status UI (progression 30/30 visible)
- [x] TimePicker format 24h automatique

### 🚧 v1.3 (Mars 2026) - En cours
- [ ] Tests automatisés complets (>70% coverage)
- [ ] Documentation complète développeur (JavaDoc)
- [ ] CI/CD GitHub Actions (build + tests)
- [ ] Publication GitHub repository
- [ ] Export PDF des rapports mensuels

### 🔮 v1.4 (Avril 2026) - Planifié
- [ ] Entraînement ML on-device (TensorFlow Lite)
- [ ] Isolates Dart pour training (éviter freeze UI)
- [ ] Multilingue (Anglais, Espagnol)
- [ ] Mode offline complet

### 🌟 v2.0 (T2 2026) - Vision
- [ ] Intégration wearables (Fitbit, Apple Watch)
- [ ] Mode multi-utilisateurs (partage famille/médecin)
- [ ] Synchronisation cloud chiffrée E2E
- [ ] Assistant IA conversationnel

---

## 🙏 Remerciements

- [OpenFoodFacts](https://world.openfoodfacts.org/) : Base de données alimentaire
- [Flutter](https://flutter.dev/) : Framework multiplateforme
- [Material Design 3](https://m3.material.io/) : Design System
- [fl_chart](https://pub.dev/packages/fl_chart) : Bibliothèque de graphiques
- La communauté **MICI France** pour les retours et suggestions

---

<div align="center">

**Fait avec ❤️ par Yannick KREMPP**

[⭐ Star sur GitHub](https://github.com/YOUR_USERNAME/crohnicles) · [🐛 Signaler un Bug](https://github.com/YOUR_USERNAME/crohnicles/issues) · [💡 Proposer une Feature](https://github.com/YOUR_USERNAME/crohnicles/discussions)

</div>
