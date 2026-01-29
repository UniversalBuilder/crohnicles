#!/usr/bin/env python3
"""
Crohnicles ML Training Pipeline
Trains decision tree models for symptom prediction from meal features.
Exports models to TensorFlow Lite format for on-device inference.
"""

import os
import sqlite3
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from sklearn.tree import DecisionTreeClassifier
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.metrics import (
    classification_report,
    confusion_matrix,
    accuracy_score,
    precision_recall_fscore_support,
)
import json
import pickle

# Configuration
DB_PATH = os.environ.get(
    "CROHNICLES_DB_PATH", os.path.expanduser("~/Documents/crohnicles.db")
)
MODELS_DIR = "../assets/models"
LOOKBACK_DAYS = 90
TIME_WINDOW_HOURS = 8  # Symptom window after meal
MIN_SAMPLES = 30  # Minimum training samples required

# Model hyperparameters (balanced for on-device performance)
TREE_CONFIG = {
    "max_depth": 10,
    "min_samples_split": 15,
    "min_samples_leaf": 5,
    "class_weight": "balanced",
    "random_state": 42,
}


class CrohniclesTrainer:
    def __init__(self, db_path=DB_PATH):
        self.db_path = db_path
        self.conn = None
        self.feature_names = []
        self.models = {}

    def connect_db(self):
        """Connect to SQLite database"""
        print(f"[Training] Connecting to database: {self.db_path}")
        self.conn = sqlite3.connect(self.db_path)
        print("[Training] Database connected successfully")

    def extract_training_data(self, symptom_type="pain"):
        """
        Extract feature matrix and labels from database

        Args:
            symptom_type: 'pain', 'diarrhea', or 'bloating'

        Returns:
            X (DataFrame): Feature matrix with 60+ features per meal
            y (array): Binary labels (1=symptom occurred, 0=no symptom)
        """
        print(f"\n[Training] Extracting data for symptom type: {symptom_type}")

        # Get meal-symptom pairs within time window
        query = f"""
        SELECT 
            m.id as meal_id,
            m.dateTime as meal_time,
            m.meta_data as meal_data,
            m.context_data as context_data,
            m.tags as meal_tags,
            CASE WHEN s.id IS NOT NULL THEN 1 ELSE 0 END as has_symptom
        FROM events m
        LEFT JOIN (
            SELECT e.id, e.dateTime, e.severity
            FROM events e
            WHERE e.type = 'symptom'
            AND e.tags LIKE '%{symptom_type}%'
            AND e.dateTime >= datetime('now', '-{LOOKBACK_DAYS} days')
        ) s ON (
            julianday(s.dateTime) - julianday(m.dateTime)
        ) * 24 BETWEEN 4 AND {TIME_WINDOW_HOURS}
        WHERE m.type = 'meal'
        AND m.dateTime >= datetime('now', '-{LOOKBACK_DAYS} days')
        ORDER BY m.dateTime DESC
        """

        df = pd.read_sql_query(query, self.conn)
        print(f"[Training] Found {len(df)} meal events")
        print(
            f"[Training] Positive samples (with {symptom_type}): {df['has_symptom'].sum()}"
        )

        if len(df) < MIN_SAMPLES:
            raise ValueError(
                f"Insufficient training data: {len(df)} samples (minimum {MIN_SAMPLES})"
            )

        # Extract features from each meal
        features_list = []
        for _, row in df.iterrows():
            features = self._extract_features(row)
            features_list.append(features)

        X = pd.DataFrame(features_list)
        y = df["has_symptom"].values

        # Store feature names for later use
        self.feature_names = X.columns.tolist()

        print(f"[Training] Feature matrix shape: {X.shape}")
        print(f"[Training] Features: {len(self.feature_names)} columns")
        print(f"[Training] Class distribution: {np.bincount(y)}")

        return X, y

    def _extract_features(self, row):
        """
        Extract 60+ features from a meal event
        Mirrors the feature_extractor.dart implementation
        """
        features = {}

        # Parse meal data
        try:
            meal_data = json.loads(row["meal_data"]) if row["meal_data"] else {}
            foods = meal_data.get("foods", [])
            tags = row["meal_tags"].split(",") if row["meal_tags"] else []
        except:
            foods = []
            tags = []

        # Parse context data
        try:
            context = json.loads(row["context_data"]) if row["context_data"] else {}
        except:
            context = {}

        # Meal tags (11 features)
        tag_features = [
            "feculent",
            "proteine",
            "legume",
            "produit_laitier",
            "fruit",
            "epices",
            "gras",
            "sucre",
            "fermente",
            "gluten",
            "alcool",
        ]
        for tag in tag_features:
            features[f"tag_{tag}"] = (
                1.0 if tag.lower() in [t.lower() for t in tags] else 0.0
            )

        # Nutrition aggregation (9 features)
        nutrition = self._aggregate_nutrition(foods)
        features.update(nutrition)

        # Processing level (2 features)
        features["nova_group"] = 2.0  # Default to minimally processed
        features["is_processed"] = (
            1.0 if any("industriel" in t.lower() for t in tags) else 0.0
        )

        # Timing features (11 features)
        meal_time = datetime.fromisoformat(row["meal_time"])
        features["hour_of_day"] = meal_time.hour
        features["day_of_week"] = meal_time.weekday()
        features["is_weekend"] = 1.0 if meal_time.weekday() >= 5 else 0.0
        features["is_breakfast"] = 1.0 if 6 <= meal_time.hour < 10 else 0.0
        features["is_lunch"] = 1.0 if 11 <= meal_time.hour < 15 else 0.0
        features["is_dinner"] = 1.0 if 18 <= meal_time.hour < 22 else 0.0
        features["is_snack"] = 1.0 if "snack" in [t.lower() for t in tags] else 0.0
        features["is_late_night"] = (
            1.0 if meal_time.hour >= 22 or meal_time.hour < 6 else 0.0
        )
        features["minutes_since_last_meal"] = 240.0  # Default 4h
        features["hours_since_last_meal"] = 4.0
        features["meals_today_count"] = 3.0  # Default estimate

        # Weather/context (10 features) - Convert string values to float
        features["temperature_celsius"] = float(context.get("temperature", 20.0))
        features["pressure_hpa"] = float(context.get("barometricPressure", 1013.0))
        features["pressure_change_6h"] = float(context.get("pressureChange6h", 0.0))
        features["humidity"] = float(context.get("humidity", 50.0))
        features["is_high_humidity"] = (
            1.0 if float(context.get("humidity", 50)) > 70 else 0.0
        )
        features["is_pressure_dropping"] = (
            1.0 if float(context.get("pressureChange6h", 0)) < -3 else 0.0
        )
        weather = context.get("weatherCondition", "unknown")
        features["weather_sunny"] = 1.0 if weather == "sunny" else 0.0
        features["weather_rainy"] = 1.0 if weather == "rainy" else 0.0
        features["weather_cloudy"] = 1.0 if weather == "cloudy" else 0.0
        features["weather_stormy"] = 1.0 if weather == "stormy" else 0.0

        # Time/season (8 features)
        time_of_day = context.get("timeOfDay", "afternoon")
        features["time_morning"] = 1.0 if time_of_day == "morning" else 0.0
        features["time_afternoon"] = 1.0 if time_of_day == "afternoon" else 0.0
        features["time_evening"] = 1.0 if time_of_day == "evening" else 0.0
        features["time_night"] = 1.0 if time_of_day == "night" else 0.0
        season = context.get("season", "summer")
        features["season_spring"] = 1.0 if season == "spring" else 0.0
        features["season_summer"] = 1.0 if season == "summer" else 0.0
        features["season_fall"] = 1.0 if season == "fall" else 0.0
        features["season_winter"] = 1.0 if season == "winter" else 0.0

        return features

    def _aggregate_nutrition(self, foods):
        """Aggregate nutrition data from food list"""
        nutrition = {
            "protein_g": 0.0,
            "fat_g": 0.0,
            "carb_g": 0.0,
            "fiber_g": 0.0,
            "sugar_g": 0.0,
            "energy_kcal": 0.0,
        }

        for food in foods:
            nutrition["protein_g"] += food.get("proteins", 0.0)
            nutrition["fat_g"] += food.get("fats", 0.0)
            nutrition["carb_g"] += food.get("carbs", 0.0)
            nutrition["fiber_g"] += food.get("fiber", 0.0)
            nutrition["sugar_g"] += food.get("sugars", 0.0)

        # Calculate energy
        nutrition["energy_kcal"] = (
            nutrition["protein_g"] * 4
            + nutrition["fat_g"] * 9
            + nutrition["carb_g"] * 4
        )

        # Calculate macronutrient percentages
        total_calories = nutrition["energy_kcal"] if nutrition["energy_kcal"] > 0 else 1
        nutrition["protein_pct"] = (nutrition["protein_g"] * 4) / total_calories * 100
        nutrition["fat_pct"] = (nutrition["fat_g"] * 9) / total_calories * 100
        nutrition["carb_pct"] = (nutrition["carb_g"] * 4) / total_calories * 100

        return nutrition

    def train_model_with_tag(self, symptom_type, french_tag):
        """Train decision tree classifier using French symptom tag"""
        print(f"\n{'='*60}")
        print(f"Training model for: {symptom_type.upper()} (tag: {french_tag})")
        print(f"{'='*60}")

        # Extract data using French tag
        X, y = self.extract_training_data_with_tag(french_tag)

        # Split into train/test
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42, stratify=y
        )

        print(f"\n[Training] Train set: {len(X_train)} samples")
        print(f"[Training] Test set: {len(X_test)} samples")

        # Train decision tree
        print(
            f"\n[Training] Training DecisionTreeClassifier with config: {TREE_CONFIG}"
        )
        clf = DecisionTreeClassifier(**TREE_CONFIG)
        clf.fit(X_train, y_train)

        # Evaluate
        y_pred = clf.predict(X_test)
        accuracy = accuracy_score(y_test, y_pred)
        precision, recall, f1, _ = precision_recall_fscore_support(
            y_test, y_pred, average="binary", zero_division=0
        )

        print(f"\n[Evaluation] Test Set Performance:")
        print(f"  Accuracy:  {accuracy:.3f}")
        print(f"  Precision: {precision:.3f}")
        print(f"  Recall:    {recall:.3f}")
        print(f"  F1 Score:  {f1:.3f}")

        print(f"\n[Evaluation] Confusion Matrix:")
        print(confusion_matrix(y_test, y_pred))

        print(f"\n[Evaluation] Classification Report:")
        print(
            classification_report(
                y_test, y_pred, target_names=["No symptom", "Symptom"], zero_division=0
            )
        )

        # Cross-validation
        cv_scores = cross_val_score(
            clf, X_train, y_train, cv=min(5, len(X_train) // 2), scoring="f1"
        )
        print(
            f"\n[Evaluation] Cross-Validation F1: {cv_scores.mean():.3f} (+/- {cv_scores.std():.3f})"
        )

        # Feature importance
        feature_importance = pd.DataFrame(
            {"feature": self.feature_names, "importance": clf.feature_importances_}
        ).sort_values("importance", ascending=False)

        print(f"\n[Feature Importance] Top 10 features for {symptom_type}:")
        print(feature_importance.head(10).to_string(index=False))

        # Store model and metrics
        self.models[symptom_type] = {
            "model": clf,
            "accuracy": accuracy,
            "precision": precision,
            "recall": recall,
            "f1": f1,
            "feature_importance": feature_importance.to_dict("records"),
            "feature_names": self.feature_names,
        }

        return clf, accuracy, precision, recall, f1

    def extract_training_data_with_tag(self, french_tag):
        """
        Extract feature matrix and labels from database using French symptom tag
        """
        print(f"\n[Training] Extracting data for symptom tag: {french_tag}")

        # Get meal-symptom pairs within time window
        query = f"""
        SELECT 
            m.id as meal_id,
            m.dateTime as meal_time,
            m.meta_data as meal_data,
            m.context_data as context_data,
            m.tags as meal_tags,
            CASE WHEN s.id IS NOT NULL THEN 1 ELSE 0 END as has_symptom
        FROM events m
        LEFT JOIN (
            SELECT e.id, e.dateTime, e.severity
            FROM events e
            WHERE e.type = 'symptom'
            AND e.tags LIKE '%{french_tag}%'
            AND e.dateTime >= datetime('now', '-{LOOKBACK_DAYS} days')
        ) s ON (
            julianday(s.dateTime) - julianday(m.dateTime)
        ) * 24 BETWEEN 4 AND {TIME_WINDOW_HOURS}
        WHERE m.type = 'meal'
        AND m.dateTime >= datetime('now', '-{LOOKBACK_DAYS} days')
        ORDER BY m.dateTime DESC
        """

        df = pd.read_sql_query(query, self.conn)
        print(f"[Training] Found {len(df)} meal events")
        print(
            f"[Training] Positive samples (with {french_tag}): {df['has_symptom'].sum()}"
        )

        if len(df) < MIN_SAMPLES:
            raise ValueError(
                f"Insufficient training data: {len(df)} samples (minimum {MIN_SAMPLES})"
            )

        # Extract features from each meal
        features_list = []
        for _, row in df.iterrows():
            features = self._extract_features(row)
            features_list.append(features)

        X = pd.DataFrame(features_list)
        y = df["has_symptom"].values

        # Store feature names for later use
        self.feature_names = X.columns.tolist()

        print(f"[Training] Feature matrix shape: {X.shape}")
        print(f"[Training] Features: {len(self.feature_names)} columns")
        print(f"[Training] Class distribution: {np.bincount(y)}")

        return X, y

    def train_model(self, symptom_type):
        """Train decision tree classifier for a specific symptom"""
        print(f"\n{'='*60}")
        print(f"Training model for: {symptom_type.upper()}")
        print(f"{'='*60}")

        # Extract data
        X, y = self.extract_training_data(symptom_type)

        # Split into train/test
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42, stratify=y
        )

        print(f"\n[Training] Train set: {len(X_train)} samples")
        print(f"[Training] Test set: {len(X_test)} samples")

        # Train decision tree
        print(
            f"\n[Training] Training DecisionTreeClassifier with config: {TREE_CONFIG}"
        )
        clf = DecisionTreeClassifier(**TREE_CONFIG)
        clf.fit(X_train, y_train)

        # Evaluate
        y_pred = clf.predict(X_test)
        accuracy = accuracy_score(y_test, y_pred)
        precision, recall, f1, _ = precision_recall_fscore_support(
            y_test, y_pred, average="binary"
        )

        print(f"\n[Evaluation] Test Set Performance:")
        print(f"  Accuracy:  {accuracy:.3f}")
        print(f"  Precision: {precision:.3f}")
        print(f"  Recall:    {recall:.3f}")
        print(f"  F1 Score:  {f1:.3f}")

        print(f"\n[Evaluation] Confusion Matrix:")
        print(confusion_matrix(y_test, y_pred))

        print(f"\n[Evaluation] Classification Report:")
        print(
            classification_report(
                y_test, y_pred, target_names=["No symptom", "Symptom"]
            )
        )

        # Cross-validation
        cv_scores = cross_val_score(clf, X_train, y_train, cv=5, scoring="f1")
        print(
            f"\n[Evaluation] 5-Fold Cross-Validation F1: {cv_scores.mean():.3f} (+/- {cv_scores.std():.3f})"
        )

        # Feature importance
        feature_importance = pd.DataFrame(
            {"feature": self.feature_names, "importance": clf.feature_importances_}
        ).sort_values("importance", ascending=False)

        print(f"\n[Feature Importance] Top 10 features for {symptom_type}:")
        print(feature_importance.head(10).to_string(index=False))

        # Store model and metrics
        self.models[symptom_type] = {
            "model": clf,
            "accuracy": accuracy,
            "precision": precision,
            "recall": recall,
            "f1": f1,
            "feature_importance": feature_importance.to_dict("records"),
            "feature_names": self.feature_names,
        }

        return clf, accuracy, precision, recall, f1

    def export_to_tflite(self, symptom_type):
        """Convert decision tree to TensorFlow Lite format"""
        print(f"\n[Export] Converting {symptom_type} model to TFLite format...")

        if symptom_type not in self.models:
            raise ValueError(f"Model for {symptom_type} not trained yet")

        clf = self.models[symptom_type]["model"]

        # Create a simple wrapper model for TFLite conversion
        # Decision trees don't directly convert, so we use a functional approach
        # For production, consider using XGBoost or LightGBM with native TFLite support

        # For now, we'll save the sklearn model and feature names for Dart-side inference
        # using a custom interpreter (this is a simplified approach for demo)

        model_dir = os.path.join(os.path.dirname(__file__), MODELS_DIR)
        os.makedirs(model_dir, exist_ok=True)

        # Save model metadata
        metadata = {
            "symptom_type": symptom_type,
            "feature_names": self.feature_names,
            "tree_structure": self._serialize_tree(clf),
            "metrics": {
                "accuracy": self.models[symptom_type]["accuracy"],
                "precision": self.models[symptom_type]["precision"],
                "recall": self.models[symptom_type]["recall"],
                "f1": self.models[symptom_type]["f1"],
            },
            "training_date": datetime.now().isoformat(),
            "lookback_days": LOOKBACK_DAYS,
            "time_window_hours": TIME_WINDOW_HOURS,
        }

        model_path = os.path.join(model_dir, f"{symptom_type}_predictor.json")
        with open(model_path, "w") as f:
            json.dump(metadata, f, indent=2)

        print(f"[Export] Model saved to: {model_path}")
        print(
            f"[Export] Note: For production, integrate with tflite_flutter using TF Decision Forests"
        )

        return model_path

    def _serialize_tree(self, clf):
        """Serialize decision tree structure for JSON export"""
        tree = clf.tree_

        def recurse(node_id):
            if tree.feature[node_id] == -2:  # Leaf node
                return {
                    "is_leaf": True,
                    "value": int(np.argmax(tree.value[node_id][0])),
                    "probability": float(
                        tree.value[node_id][0][1] / tree.value[node_id][0].sum()
                    ),
                }
            else:
                return {
                    "is_leaf": False,
                    "feature": self.feature_names[tree.feature[node_id]],
                    "threshold": float(tree.threshold[node_id]),
                    "left": recurse(tree.children_left[node_id]),
                    "right": recurse(tree.children_right[node_id]),
                }

        return recurse(0)

    def save_training_history(self):
        """Save training metrics to database"""
        print(f"\n[Database] Saving training history...")

        try:
            cursor = self.conn.cursor()
            saved_count = 0

            for symptom_type, metrics in self.models.items():
                # Skip models that didn't complete training (no feature_importances)
                if "feature_importances" not in metrics:
                    print(
                        f"[Database] Skipping {symptom_type} - training not completed"
                    )
                    continue

                # Convert feature importances to JSON string
                feature_imp = json.dumps(
                    dict(
                        zip(self.feature_names, metrics["feature_importances"].tolist())
                    )
                )

                cursor.execute(
                    """
                    INSERT INTO training_history 
                    (model_name, trained_at, sample_size, accuracy, precision_val, recall_val, f1_score, feature_importances, validation_passed)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                    (
                        symptom_type,
                        datetime.now().isoformat(),
                        metrics["sample_size"],
                        float(metrics["accuracy"]),
                        float(metrics["precision"]),
                        float(metrics["recall"]),
                        float(metrics["f1"]),
                        feature_imp,
                        1,  # validation_passed = true
                    ),
                )
                saved_count += 1

            self.conn.commit()
            print(f"[Database] Training history saved for {saved_count} models")
        except Exception as e:
            print(f"[Database] Error saving training history: {e}")
            import traceback

            traceback.print_exc()

    def close(self):
        """Close database connection"""
        if self.conn:
            self.conn.close()
            print("\n[Training] Database connection closed")


def main():
    """Main training pipeline"""
    print("=" * 60)
    print("Crohnicles ML Training Pipeline")
    print("=" * 60)
    print(f"Start time: {datetime.now()}")
    print(f"Database: {DB_PATH}")
    print(f"Lookback period: {LOOKBACK_DAYS} days")
    print(f"Symptom window: {TIME_WINDOW_HOURS} hours after meal")
    print("=" * 60)

    trainer = CrohniclesTrainer(DB_PATH)

    try:
        trainer.connect_db()

        # Comprehensive symptom mappings for all IBD manifestations
        # Includes intestinal and extra-intestinal symptoms
        symptom_mappings = {
            # Intestinal symptoms
            "pain": "Inflammation",  # Abdominal pain, inflammation
            "diarrhea": "Urgent",  # Diarrhea, urgency
            "bloating": "Gaz",  # Gas, bloating, distension
            # Extra-intestinal manifestations
            "joints": "Articulations",  # Joint pain (arthralgia)
            "skin": "Peau",  # Skin manifestations (erythema nodosum, etc.)
            "oral": "Bouche/ORL",  # Oral/ocular/ENT symptoms (aphthae, uveitis)
            "systemic": "Général",  # Systemic symptoms (fatigue, fever)
        }

        # Auto-detect which tags have sufficient data
        print("\n[Auto-detection] Checking available symptom data...")
        cursor = trainer.conn.cursor()

        available_mappings = {}
        for model_key, french_tag in symptom_mappings.items():
            # Count symptoms with this tag
            cursor.execute(
                """
                SELECT COUNT(*) 
                FROM events 
                WHERE type = 'symptom' 
                AND tags LIKE ?
                AND dateTime >= datetime('now', '-90 days')
            """,
                (f"%{french_tag}%",),
            )
            count = cursor.fetchone()[0]

            if count >= 5:  # Minimum threshold for attempting training
                available_mappings[model_key] = french_tag
                print(
                    f"  [OK] {model_key} ({french_tag}): {count} samples - will attempt training"
                )
            else:
                print(
                    f"  [SKIP] {model_key} ({french_tag}): {count} samples - skipping (need 5+)"
                )

        if not available_mappings:
            print("\n[Error] No symptom types have sufficient data for training")
            print("[Hint] Log some symptoms in the app, then try training again")
            return

        print(f"\n[Training] Proceeding with {len(available_mappings)} symptom types")

        for symptom_type, french_tag in available_mappings.items():
            try:
                # Extract data using French tag but save as English model name
                trainer.train_model_with_tag(symptom_type, french_tag)
                trainer.export_to_tflite(symptom_type)
            except ValueError as e:
                print(f"\n[Warning] Skipping {symptom_type}: {e}")
                continue

        # Save training history to database
        if trainer.models:
            trainer.save_training_history()

            print("\n" + "=" * 60)
            print("Training Complete!")
            print(f"Models trained: {list(trainer.models.keys())}")
            print(f"End time: {datetime.now()}")
            print("=" * 60)
        else:
            print("\n[Error] No models were successfully trained")

    except Exception as e:
        print(f"\n[Error] Training failed: {e}")
        import traceback

        traceback.print_exc()
    finally:
        trainer.close()


if __name__ == "__main__":
    main()
