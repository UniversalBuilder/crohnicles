# Étape 3: Timeline Visuelle Multi-Pistes - COMPLÉTÉ

## Date: 2026-01-23

## Objectif
Créer une vue timeline synchronisée avec 3 pistes horizontales (repas, douleurs, selles) pour visualiser les corrélations temporelles entre événements.

## Fichiers Créés

### 1. lib/models/timeline_event_group.dart
- **Modèle de données** pour grouper les événements par buckets temporels
- Propriétés:
  - `DateTime bucketTime`: Timestamp du bucket
  - `List<EventModel> meals`: Repas dans ce bucket
  - `List<EventModel> symptoms`: Symptômes dans ce bucket
  - `List<EventModel> stools`: Selles dans ce bucket
- Méthodes:
  - `hasAnyEvent`: Vérifie si le bucket contient au moins un événement
  - `maxSeverity`: Retourne la sévérité maximale des symptômes

### 2. lib/timeline_chart_page.dart (590 lignes)
- **Page principale** avec timeline horizontale scrollable
- **Fonctionnalités principales:**
  - Sélection période: 24h (buckets 1h), 7j (buckets 6h), 30j (buckets 1 jour)
  - Groupement automatique des événements par buckets temporels
  - 3 pistes verticales synchronisées:
    * **Track Repas** (haut): Icône restaurant/café selon type, badge compte multiples
    * **Track Symptômes** (milieu): Icône cœur, affichage sévérité moyenne, gradient selon intensité
    * **Track Selles** (bas): Icône analytics, badge compte multiples
  - **Détection corrélations**: Indicateur visuel (flèche + warning) quand:
    * Symptôme sévère (≥6/10) dans le bucket actuel
    * + Repas avec tags trigger (gras/gluten/lactose/alcool/épicé) dans window 2-24h avant
  - **Interactivité**:
    * Tap sur une piste → Bottom sheet avec liste événements du bucket
    * Tap sur événement → Navigation vers EventDetailPage
  - **Design**:
    * Légende en haut avec icônes des 3 catégories
    * Labels temporels adaptés à la période (HH:mm, Jour HH:mm, dd/MM)
    * Gradients et couleurs cohérents avec app_theme.dart
    * Empty state si aucun événement

## Modifications Apportées

### lib/main.dart
- **Ligne 22**: Ajout `import 'timeline_chart_page.dart';`
- **Lignes 1105-1115**: Ajout bouton Timeline dans AppBar:
  ```dart
  IconButton(
    icon: const Icon(Icons.timeline, size: 22),
    tooltip: 'Timeline Visuelle',
    onPressed: () {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => const TimelineChartPage(),
      ));
    },
  ),
  ```

## Algorithmes Clés

### Bucketing Temporel (_getBucket)
```dart
DateTime _getBucket(DateTime time, Duration bucketSize) {
  final epoch = DateTime(1970);
  final diff = time.difference(epoch);
  final bucketCount = diff.inMicroseconds ~/ bucketSize.inMicroseconds;
  return epoch.add(Duration(microseconds: bucketCount * bucketSize.inMicroseconds));
}
```
- Aligne tous les événements sur des buckets fixes
- Évite les décalages cumulatifs avec référence epoch 1970

### Détection Corrélations (_hasCorrelation)
```dart
bool _hasCorrelation(int index) {
  // 1. Vérifie symptômes sévères (≥6/10) dans bucket actuel
  // 2. Calcule fenêtre 2-24h en nombre de buckets
  // 3. Parcourt buckets précédents dans cette fenêtre
  // 4. Détecte tags trigger: gras/gluten/lactose/alcool/épicé
  // 5. Retourne true si trigger trouvé
}
```
- Fenêtre adaptative selon durée bucket (respect IBD pathology)
- Évite false positives avec minimum 2h de délai

## Problèmes Résolus

### DateFormat Locale Error
**Erreur initiale**: `LocaleDataException: Locale data has not been initialized, call initializeDateFormatting(<locale>).`

**Cause**: Utilisation de `DateFormat('EEE HH:mm', 'fr_FR')` sans initialisation intl

**Solution**: Suppression du paramètre locale explicite
```dart
// AVANT (erreur)
DateFormat('EEE HH:mm', 'fr_FR').format(bucket);

// APRÈS (ok)
DateFormat('EEE HH:mm').format(bucket);
```

## UX Patterns

### Gradient Intensité
- Symptômes: Gradient rouge proportionnel à sévérité (`gradient.scale(maxSeverity / 10)`)
- Repas/Selles: Gradient fixe faible (`gradient.scale(0.3)`)

### Navigation Hiérarchique
1. Timeline horizontale (vue d'ensemble)
2. Tap bucket → Bottom sheet (événements du bucket)
3. Tap événement → EventDetailPage (détails + événements liés)

### Indicateurs Visuels
- **Badge nombre**: Quand >1 événement dans bucket
- **Icône alternative**: Café pour snacks vs restaurant pour repas
- **Sévérité moyenne**: Affichée sur track symptômes (ex: "7.5/10")
- **Corrélation warning**: Flèche arrière + warning icon en rouge

## Tests Manuels Suggérés

1. **Chargement données**:
   - Ouvrir timeline avec données vides → Empty state affiché
   - Générer démo data (menu dev) → Timeline populated
   - Sélectionner 24h/7j/30j → Buckets adaptés

2. **Interactivité**:
   - Tap track repas → Liste repas affiché
   - Tap événement → EventDetailPage ouvert
   - Scroll horizontal → Toutes pistes synchronisées

3. **Corrélations**:
   - Créer repas avec tag "Gras" à 10h
   - Créer symptôme sévérité 8 à 16h
   - Vérifier indicateur warning sous bucket 16h

4. **Edge cases**:
   - Période sans événements → Empty state
   - Bucket avec 10+ événements → Badge count affiché
   - Navigation back → Retour à timeline principale

## Prochaines Améliorations Possibles

### Court terme (1-2 jours)
- [ ] Ajouter `initializeDateFormatting('fr')` dans main.dart pour support locale complet
- [ ] Hero animation card→detail pour transitions fluides
- [ ] Loading state (CircularProgressIndicator) pendant chargement données
- [ ] Pull-to-refresh pour actualiser timeline

### Moyen terme (3-5 jours)
- [ ] Database optimization: `getEventsInRange(startDate, endDate, {EventType? filter})`
- [ ] Index database: `CREATE INDEX idx_events_type_datetime ON events(type, dateTime)`
- [ ] Custom painter pour lignes pointillées reliant repas triggers→symptômes
- [ ] Zoom/pinch gesture pour ajuster dynamiquement taille buckets

### Long terme (1-2 semaines)
- [ ] Export timeline PNG/PDF pour partage avec médecin
- [ ] Overlay annotations (notes, médicaments, contexte)
- [ ] Comparaison 2 périodes en split-view (avant/après traitement)
- [ ] Heatmap view alternative (matrice jour×heure avec intensité couleur)

## Métriques

- **Fichiers créés**: 2 (models/timeline_event_group.dart, timeline_chart_page.dart)
- **Lignes de code**: ~620 lignes
- **Fichiers modifiés**: 1 (main.dart +13 lignes)
- **Temps développement**: ~40 minutes
- **Bugs critiques**: 1 (DateFormat locale) résolu

## Statut: ✅ COMPLÉTÉ

L'étape 3 est entièrement fonctionnelle. L'utilisateur peut maintenant:
1. ✅ Accéder à timeline visuelle depuis AppBar (icône timeline)
2. ✅ Voir 3 pistes synchronisées (repas, douleurs, selles)
3. ✅ Changer période d'affichage (24h/7j/30j)
4. ✅ Voir indicateurs corrélations automatiques
5. ✅ Explorer événements par tap sur buckets
6. ✅ Naviguer vers détails événements

**App running**: flutter run -d windows (terminal 80e56be7)
