# Crohnicles ML Training Pipeline

This directory contains the Python training pipeline for Crohnicles ML models.

## Overview

The training pipeline extracts meal and symptom data from the SQLite database, trains decision tree classifiers for three symptom types (pain, diarrhea, bloating), and exports models for on-device inference.

## Setup

1. Install Python 3.9+ if not already installed
2. Install dependencies:
```bash
pip install -r requirements.txt
```

## Usage

### Manual Training
Run the training script manually:
```bash
python train_models.py
```

### Automated Training
The app will automatically retrain models nightly using the `training_service.dart` workmanager integration (Phase 2, Week 4).

## Training Process

1. **Data Extraction**: Queries last 90 days of meals and symptoms from database
2. **Feature Engineering**: Extracts 60+ features (tags, nutrition, timing, weather, context)
3. **Model Training**: Trains DecisionTreeClassifier for each symptom type
   - Max depth: 10
   - Min samples split: 15
   - Class weight: balanced
4. **Evaluation**: Reports accuracy, precision, recall, F1 score, confusion matrix
5. **Export**: Saves model structure and metadata to JSON (assets/models/)
6. **History**: Stores training metrics in `training_history` table

## Minimum Requirements

- **Training samples**: 30+ meal events
- **Time window**: Symptoms occurring 4-8 hours after meal
- **Lookback period**: 90 days

## Output

Models are saved to `../assets/models/`:
- `pain_predictor.json` - Pain prediction model + metadata
- `diarrhea_predictor.json` - Diarrhea prediction model + metadata
- `bloating_predictor.json` - Bloating prediction model + metadata

Each JSON file contains:
- Serialized decision tree structure
- Feature names (60+ features)
- Training metrics (accuracy, precision, recall, F1)
- Feature importance rankings
- Metadata (training date, lookback period, time window)

## Integration with Flutter

The `model_manager.dart` service loads these JSON models and performs on-device inference using the decision tree structure. This avoids needing TFLite for simple decision trees while maintaining interpretability.

## Future Enhancements

For production scale:
- Migrate to TensorFlow Decision Forests for native TFLite export
- Add hyperparameter tuning with GridSearchCV
- Implement ensemble methods (RandomForest, XGBoost)
- Add SHAP values for model explainability
- Support incremental learning
