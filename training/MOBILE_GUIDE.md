# Guide ML Mobile - Crohnicles

## ⚠️ Limitation Mobile

**L'entraînement des modèles ML n'est PAS disponible sur Android/iOS** car:

1. Python n'est pas disponible nativement sur mobile
2. Le script `train_models.py` nécessite scikit-learn (package Python)
3. L'entraînement est CPU-intensif (inadapté pour batteries mobiles)

## ✅ Solutions pour Mobile

### Option 1: Modèles Pré-entraînés (Recommandé)

Les modèles inclus dans l'application fonctionnent automatiquement:

- `assets/models/bloating_predictor.json` ✅
- `assets/models/pain_predictor.json` (à venir)
- `assets/models/diarrhea_predictor.json` (à venir)

**Aucune action requise** - les modèles se chargent au démarrage de l'app.

### Option 2: Entraîner sur Desktop et Synchroniser

1. **Sur votre ordinateur Windows/Mac/Linux:**
   ```bash
   cd projet/crohnicles
   flutter run -d windows
   # Dans l'app: Insights → 🤖 Entraînement
   ```

2. **Les modèles sont créés dans:**
   ```
   projet/crohnicles/assets/models/
   ├── pain_predictor.json
   ├── diarrhea_predictor.json
   └── bloating_predictor.json
   ```

3. **Rebuild l'app mobile:**
   ```bash
   flutter build apk --release
   flutter install
   ```

Les nouveaux modèles seront inclus dans le build Android.

### Option 3: Backend Cloud (Avancé)

Créer un serveur qui entraîne les modèles:

```python
# server.py - Flask API pour entraînement distant
from flask import Flask, request, jsonify
import subprocess

app = Flask(__name__)

@app.route('/train', methods=['POST'])
def train_models():
    db_data = request.json['database']
    # Sauvegarder DB temporairement
    # Lancer train_models.py
    result = subprocess.run(['python', 'train_models.py'])
    # Renvoyer les fichiers JSON
    return jsonify({'models': ['pain', 'diarrhea', 'bloating']})
```

**App mobile:**
```dart
// Envoyer données au serveur
final response = await http.post(
  'https://votre-serveur.com/train',
  body: jsonEncode({'database': dbSnapshot}),
);

// Télécharger modèles
final models = await http.get('https://votre-serveur.com/models');
// Sauvegarder dans assets/
```

## 🔧 Utilisation des Modèles sur Mobile

### Chargement Automatique

```dart
// Lors du démarrage de l'app
final modelManager = ModelManager();
await modelManager.initialize();

if (modelManager.isReady) {
  print('✅ ${modelManager.loadedModels.length} modèles chargés');
} else {
  print('⚠️ Aucun modèle - utilisation corrélation-based');
}
```

### Prédictions

```dart
// Prédire risques pour un repas
final predictions = await modelManager.predictAllSymptoms(
  mealEvent,
  context,
);

for (final pred in predictions) {
  print('${pred.symptomType}: ${pred.riskEmoji}');
  print('Score: ${(pred.riskScore * 100).toInt()}%');
  print('Facteurs: ${pred.topFactors.take(3).map((f) => f.humanReadable).join(", ")}');
}
```

### Affichage dans l'UI

```dart
// Meal composer dialog - afficher prédictions
Widget _buildRiskPreview() {
  return Column(
    children: predictions.map((pred) => Card(
      color: pred.riskScore > 0.7 ? Colors.red[50] : Colors.green[50],
      child: ListTile(
        leading: Text(pred.riskEmoji, style: TextStyle(fontSize: 32)),
        title: Text('${pred.symptomType}: ${(pred.riskScore * 100).toInt()}%'),
        subtitle: Text(pred.explanation),
      ),
    )).toList(),
  );
}
```

## 📊 Vérifier les Modèles Disponibles

### Via l'interface

1. Ouvrir **Insights**
2. Cliquer sur **Statut des Modèles**
3. Vérifier quels modèles sont chargés

### Via les logs

```bash
adb logcat | grep ModelManager
# Sortie:
# I/flutter: [ModelManager] ✅ Loaded bloating model
# I/flutter: [ModelManager] ⚠️ pain model not found
# I/flutter: [ModelManager] ⚠️ diarrhea model not found
```

## 🚀 Amélioration Future: TFLite Flutter

Pour entraînement natif sur mobile (complexe):

1. **Convertir arbres de décision → TFLite:**
   ```python
   # Utiliser TensorFlow Decision Forests
   import tensorflow_decision_forests as tfdf
   
   model = tfdf.keras.RandomForestModel()
   model.fit(X_train, y_train)
   
   # Convertir en TFLite
   converter = tf.lite.TFLiteConverter.from_keras_model(model)
   tflite_model = converter.convert()
   ```

2. **Utiliser tflite_flutter en Dart:**
   ```dart
   import 'package:tflite_flutter/tflite_flutter.dart';
   
   final interpreter = await Interpreter.fromAsset('models/pain.tflite');
   interpreter.run(inputFeatures, outputBuffer);
   ```

**Avantages:**
- Inférence ultra-rapide sur mobile
- Taille modèle réduite (~50KB vs 200KB JSON)
- Support GPU/NPU Android

**Inconvénients:**
- Nécessite migration complète du pipeline
- Conversion arbres→TFLite complexe
- Debugging plus difficile

## ❓ FAQ

**Q: Pourquoi le bouton d'entraînement affiche une erreur sur Android?**

R: C'est normal. Le bouton est laissé visible avec un tooltip explicite "Desktop uniquement" pour informer les utilisateurs. Le message d'erreur explique clairement:

> "L'entraînement n'est disponible que sur ordinateur (Windows/Mac/Linux).
> Sur mobile, utilisez les modèles pré-entraînés ou synchronisez depuis votre ordinateur."

**Q: Les modèles sont-ils automatiquement mis à jour?**

R: Non. Pour mettre à jour les modèles sur mobile:
1. Entraîner sur desktop
2. Rebuild l'APK avec `flutter build apk`
3. Réinstaller l'app

**Q: Puis-je utiliser l'app sans modèles?**

R: Oui! L'app utilise une méthode de corrélation basique (heuristiques) si aucun modèle n'est disponible:

```dart
// Fallback: corrélation simple
double riskScore = 0.3;
if (tags.contains('gras')) riskScore += 0.2;
if (tags.contains('gluten')) riskScore += 0.15;
// ...
```

**Q: Combien de données faut-il pour entraîner?**

R: Minimum **30 repas + 10 symptômes** dans les 90 derniers jours, avec symptômes dans la fenêtre 4-8h après les repas.

## 📝 Résumé

| Fonctionnalité | Desktop | Mobile |
|----------------|---------|--------|
| Entraînement modèles | ✅ | ❌ |
| Inférence (prédictions) | ✅ | ✅ |
| Chargement modèles JSON | ✅ | ✅ |
| Corrélations basiques | ✅ | ✅ |
| Hot reload | ✅ | ✅ |

**Workflow recommandé:**
1. Développer et entraîner sur Windows/Mac
2. Tester prédictions dans l'app desktop
3. Rebuild APK pour mobile avec modèles mis à jour
4. Déployer sur Play Store/TestFlight
