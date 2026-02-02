/// Unified symptom taxonomy for ML training
/// Maps symptom categories to model types and provides metadata
library;

class SymptomModelConfig {
  final String modelKey;
  final String displayName;
  final List<String> sourceTags;
  final int minSamples;
  final String description;
  final String icon;

  const SymptomModelConfig({
    required this.modelKey,
    required this.displayName,
    required this.sourceTags,
    required this.minSamples,
    required this.description,
    required this.icon,
  });
}

class SymptomTaxonomy {
  /// All available symptom model configurations
  static const List<SymptomModelConfig> models = [
    SymptomModelConfig(
      modelKey: 'pain',
      displayName: 'Douleurs abdominales',
      sourceTags: ['Inflammation', 'Douleur', 'Crampes'],
      minSamples: 30,
      description: 'Prédit le risque de douleurs abdominales après un repas',
      icon: '🔴',
    ),
    SymptomModelConfig(
      modelKey: 'diarrhea',
      displayName: 'Diarrhée',
      sourceTags: ['Urgent', 'Diarrhée'],
      minSamples: 30,
      description: 'Prédit le risque de diarrhée dans les 4-8h après un repas',
      icon: '💧',
    ),
    SymptomModelConfig(
      modelKey: 'bloating',
      displayName: 'Ballonnements',
      sourceTags: ['Gaz', 'Ballonnement', 'Distension'],
      minSamples: 30,
      description: 'Prédit le risque de ballonnements et gaz après un repas',
      icon: '💨',
    ),
    SymptomModelConfig(
      modelKey: 'joints',
      displayName: 'Douleurs articulaires',
      sourceTags: ['Articulations', 'Arthralgie'],
      minSamples: 20,
      description:
          'Prédit le risque de douleurs articulaires (manifestation extra-intestinale)',
      icon: '🦴',
    ),
    SymptomModelConfig(
      modelKey: 'skin',
      displayName: 'Symptômes cutanés',
      sourceTags: ['Peau', 'Érythème', 'Aphtes cutanés'],
      minSamples: 20,
      description:
          'Prédit le risque de manifestations cutanées (érythème noueux, etc.)',
      icon: '🩹',
    ),
    SymptomModelConfig(
      modelKey: 'oral',
      displayName: 'Symptômes buccaux/ORL',
      sourceTags: ['Bouche/ORL', 'Aphtes', 'Gorge'],
      minSamples: 20,
      description: 'Prédit le risque de symptômes buccaux, oculaires ou ORL',
      icon: '👁️',
    ),
    SymptomModelConfig(
      modelKey: 'systemic',
      displayName: 'Symptômes systémiques',
      sourceTags: ['Général', 'Fatigue', 'Fièvre'],
      minSamples: 20,
      description:
          'Prédit le risque de symptômes généraux (fatigue, fièvre, etc.)',
      icon: '🌡️',
    ),
  ];

  /// Get model config by key
  static SymptomModelConfig? getByKey(String key) {
    try {
      return models.firstWhere((m) => m.modelKey == key);
    } catch (e) {
      return null;
    }
  }

  /// Infer ML tag from symptom name and category
  /// Used to ensure consistent tagging between demo data and real user input
  static String? inferMLTag(String symptomName, String category) {
    final nameLower = symptomName.toLowerCase();
    final catLower = category.toLowerCase();

    // Map symptom descriptions to ML tags
    // Priority order: check specific keywords first, then fallback to category

    // Pain-related
    if (nameLower.contains('douleur') ||
        nameLower.contains('crampe') ||
        nameLower.contains('inflammation') ||
        catLower.contains('abdomen')) {
      return 'Inflammation';
    }

    // Urgency-related (diarrhea)
    if (nameLower.contains('urgent') ||
        nameLower.contains('diarrhée') ||
        nameLower.contains('liquide')) {
      return 'Urgent';
    }

    // Gas/bloating-related
    if (nameLower.contains('gaz') ||
        nameLower.contains('ballonnement') ||
        nameLower.contains('distension')) {
      return 'Gaz';
    }

    // Joint-related
    if (catLower.contains('articulations') ||
        nameLower.contains('arthralgie')) {
      return 'Articulations';
    }

    // Skin-related
    if (catLower.contains('peau') ||
        nameLower.contains('érythème') ||
        nameLower.contains('aphte cutané')) {
      return 'Peau';
    }

    // Oral/ENT-related
    if (catLower.contains('bouche') ||
        catLower.contains('orl') ||
        nameLower.contains('aphte') ||
        nameLower.contains('gorge') ||
        nameLower.contains('yeux')) {
      return 'Bouche/ORL';
    }

    // Systemic symptoms
    if (catLower.contains('général') ||
        nameLower.contains('fatigue') ||
        nameLower.contains('fièvre') ||
        nameLower.contains('malaise')) {
      return 'Général';
    }

    return null;
  }

  /// Get all available ML tags
  static List<String> get allTags {
    final tags = <String>{};
    for (final model in models) {
      tags.addAll(model.sourceTags);
    }
    return tags.toList()..sort();
  }
}
