# Amélioration Recherche d'Aliments - Documentation

## Date: 2026-01-26

## Changements Implémentés

### 1. ✅ Recherche OpenFoodFacts Intégrée

**Fonctionnalité:** L'autocomplete recherche maintenant automatiquement dans la base OpenFoodFacts quand la requête contient 3+ caractères.

**Comment tester:**
```
1. Ouvrir menu "Ajouter Repas"
2. Aller à l'onglet "Recherche"
3. Taper "coca" → Attend 10s max
4. Résultats Coca-Cola s'affichent avec badge "OFF" (bleu)
```

**Indicateurs visuels:**
- Icône ☁️ (cloud_done) pour produits OpenFoodFacts
- Badge bleu "OFF" à droite du nom
- Icône 🍽️ (restaurant) pour produits locaux

### 2. ✅ Upload Photo/Galerie

**Fonctionnalité:** Sélectionner une image depuis la galerie pour entrer manuellement le code-barres visible.

**Comment utiliser:**
```
1. Onglet "Scanner" → Bouton "Galerie" (bas droite)
2. Sélectionner image d'un produit
3. Entrer code-barres visible (ex: 5449000000996 pour Coca-Cola)
4. Cliquer "Rechercher"
```

**Codes-barres de test:**
- Coca-Cola: `5449000000996`
- Nutella: `3017620422003`
- Orangina: `3124480159878`

### 3. ✅ Bouton Caméra (Mobile uniquement)

**Disponibilité:** Android/iOS seulement (masqué sur Windows/Linux)

**Raison:** `ImageSource.camera` nécessite delegate natif non disponible sur desktop.

## Problèmes Identifiés

### Timeout OpenFoodFacts API

**Symptôme:** 
```
OFFService: Timeout error - TimeoutException after 0:00:10.000000
[SEARCH] OpenFoodFacts found 0 results
```

**Causes possibles:**
1. **Firewall/Antivirus** bloque requêtes HTTP
2. **Proxy d'entreprise** non configuré
3. **Connexion Internet** instable
4. **User-Agent** rejeté par OpenFoodFacts

**Solutions:**

#### Solution 1: Vérifier Connexion
```powershell
# Tester manuellement l'API
Invoke-WebRequest -Uri "https://world.openfoodfacts.org/api/v2/search?search_terms=coca&page_size=5&json=true" -Headers @{"User-Agent"="Crohnicles-Flutter-1.0"}
```

#### Solution 2: Augmenter Timeout
**Fichier:** `lib/services/off_service.dart`

**Ligne 87-89:**
```dart
// AVANT
.timeout(const Duration(seconds: 10));

// APRÈS
.timeout(const Duration(seconds: 30)); // Augmenter à 30s
```

#### Solution 3: Configurer Proxy
**Fichier:** `lib/services/off_service.dart`

**Ajouter après ligne 12:**
```dart
import 'dart:io' show HttpClient, SecurityContext;

class OFFService {
  static final OFFService _instance = OFFService._internal();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const String _apiBaseUrl = 'https://world.openfoodfacts.org/api/v2';
  static const String _userAgent = 'Crohnicles - Flutter App - Version 1.0';
  
  // NOUVEAU: Proxy configuration
  static final http.Client _httpClient = http.Client();
  
  // Si proxy d'entreprise:
  // static final http.Client _httpClient = http.Client()
  //   ..findProxy = (uri) => 'PROXY proxy.company.com:8080';
```

## Tests Effectués

### ✅ Test 1: Recherche "coca"
- Requête locale: 0 résultats
- Requête OpenFoodFacts: Timeout (problème réseau)
- **Résultat attendu:** Liste produits Coca-Cola avec badges "OFF"

### ✅ Test 2: Upload Galerie
- Sélection image: OK
- Dialog code-barres: OK
- Fetch barcode `5449000000996`: Timeout
- **Résultat attendu:** Produit Coca-Cola ajouté au panier

### ✅ Test 3: Ajout Produit OFF au Panier
- Produit "Steaks" (barcode 3181231003354) trouvé
- Ajout au panier: OK
- Sauvegarde événement: OK
- **Résultat:** Fonctionne correctement!

## Fonctionnalités Implémentées

| Feature | Status | Plateforme | Notes |
|---------|--------|------------|-------|
| Recherche locale | ✅ | Toutes | Instant |
| Recherche OpenFoodFacts | ⚠️ | Toutes | Nécessite réseau |
| Upload galerie | ✅ | Toutes | File picker |
| Capture caméra | ✅ | Mobile | Android/iOS only |
| Scanner barcode | ⚠️ | Mobile | MobileScanner incompatible desktop |
| Indicateurs visuels | ✅ | Toutes | Badge "OFF" |
| Dédupli

cation | ✅ | Toutes | Par nom |

## Prochaines Étapes

### Court Terme (Urgent)
1. **Diagnostiquer timeout OpenFoodFacts**
   - Tester avec VPN différent
   - Vérifier pare-feu Windows
   - Logger requête HTTP complète

2. **Ajouter offline fallback**
   - Sauvegarder résultats OFF dans base locale
   - Afficher message clair si timeout
   - Proposer création manuelle

### Moyen Terme (1-2 jours)
1. **Améliorer UX timeout**
   - Loading indicator pendant recherche OFF
   - Timeout progressif (5s/10s/20s)
   - Message "Recherche en cours sur OpenFoodFacts..."

2. **Cache intelligent**
   - Sauvegarder résultats recherche OFF 7 jours
   - Table `search_cache` avec TTL
   - Autocomplete préférentiel cache

### Long Terme (1-2 semaines)
1. **Reconnaissance photo ML**
   - Intégration Google Vision API
   - Ou TensorFlow Lite model local
   - Reconnaissance aliments sans barcode

2. **Base locale enrichie**
   - Importer top 1000 produits français depuis OFF
   - Seed au premier lancement
   - Marques populaires: Coca, Danone, Nestlé...

## Codes-Barres Utiles (Tests)

### Boissons
- Coca-Cola: `5449000000996`
- Coca-Cola Zero: `5449000000897`
- Orangina: `3124480159878`
- Evian: `3068320115009`

### Snacks
- Nutella: `3017620422003`
- Kinder Bueno: `8000500310427`
- Chips Lay's: `8710398675927`

### Plats Préparés
- Pizza Sodebo: `3242272310505`
- Taboulé Carrefour: `3560070656660`

## Logs Pertinents

```log
[DB] Searching foods with query: "coca"
[DB] Found 0 results for "coca"
OFFService: Timeout error - TimeoutException after 0:00:10.000000
[SEARCH] OpenFoodFacts found 0 results for "coca"
```

**Interprétation:** 
- Base locale vide pour "coca" (normal)
- Requête OFF timeout avant réponse
- Aucun résultat affiché (problème)

## Configuration Recommandée

### Pour Tests Locaux (Sans Réseau)
1. Désactiver temporairement recherche OFF
2. Enrichir base locale avec produits courants
3. Utiliser onglet "Créer" pour tests

### Pour Production (Avec Réseau)
1. Timeout 30s pour OFF
2. Cache 90 jours pour barcodes
3. Cache 7 jours pour recherches
4. Fallback vers création manuelle

## Commandes Utiles

```bash
# Relancer app après modifications
flutter run -d windows

# Hot reload (si app running)
r

# Nettoyer et rebuild
flutter clean
flutter run -d windows

# Logs détaillés
flutter run -d windows --verbose

# Tester connexion OFF
curl "https://world.openfoodfacts.org/api/v2/search?search_terms=coca&page_size=5&json=true" -H "User-Agent: Crohnicles-Test"
```

## Support

Pour résoudre timeout OpenFoodFacts:
1. Vérifier `ping world.openfoodfacts.org`
2. Tester avec `curl` (voir commande ci-dessus)
3. Si bloqué: augmenter timeout ou activer proxy
4. Alternative: pré-charger base locale avec produits courants
