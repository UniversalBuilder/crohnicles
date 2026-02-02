import 'package:flutter/material.dart';

/// Widget affichant une explication détaillée d'une corrélation météo
/// Respecte la directive RÈGLE ABSOLUE: jamais de statistique sans contexte
class WeatherCorrelationExplanation extends StatelessWidget {
  final String weatherCondition;
  final int daysWithCondition;
  final int daysWithSymptoms;
  final double baselinePercentage;
  final String? symptomType; // null = tous symptômes

  const WeatherCorrelationExplanation({
    super.key,
    required this.weatherCondition,
    required this.daysWithCondition,
    required this.daysWithSymptoms,
    required this.baselinePercentage,
    this.symptomType,
  });

  /// Calcule le pourcentage de corrélation
  double get correlationPercentage {
    if (daysWithCondition == 0) return 0.0;
    return (daysWithSymptoms / daysWithCondition * 100);
  }

  /// Delta par rapport à la baseline
  double get delta => correlationPercentage - baselinePercentage;

  /// Force de la corrélation (Forte/Modérée/Faible/Aucune)
  String get strength {
    if (daysWithCondition < 3) return 'Données insuffisantes';
    if (delta.abs() < 10) return 'Aucune';
    if (delta.abs() < 20) return 'Faible';
    if (delta.abs() < 35) return 'Modérée';
    return 'Forte';
  }

  /// Couleur du badge de force
  Color strengthColor(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    switch (strength) {
      case 'Forte':
        return delta > 0 ? theme.error : Colors.green;
      case 'Modérée':
        return delta > 0 ? Colors.orange : Colors.lightGreen;
      case 'Faible':
        return Colors.grey;
      case 'Aucune':
        return Colors.blueGrey;
      default:
        return theme.outline;
    }
  }

  /// Badge de fiabilité basé sur taille échantillon
  String get reliability {
    if (daysWithCondition >= 10) return 'Fiable';
    if (daysWithCondition >= 5) return 'Indicatif';
    return 'Insuffisant';
  }

  /// Couleur du badge de fiabilité
  Color reliabilityColor(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    switch (reliability) {
      case 'Fiable':
        return theme.primary;
      case 'Indicatif':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Obtenir le label grammaticalement correct selon le type de symptôme
    String symptomLabel;
    String symptomLabelPossessif;
    switch (symptomType) {
      case 'Articulaires':
        symptomLabel = 'symptômes articulaires';
        symptomLabelPossessif = 'vos douleurs articulaires';
        break;
      case 'Fatigue':
        symptomLabel = 'fatigue';
        symptomLabelPossessif = 'votre fatigue';
        break;
      case 'Digestif':
        symptomLabel = 'symptômes digestifs';
        symptomLabelPossessif = 'vos troubles digestifs';
        break;
      default:
        symptomLabel = 'symptômes';
        symptomLabelPossessif = 'vos symptômes';
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec condition météo
            Row(
              children: [
                Icon(
                  _getWeatherIcon(),
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    weatherCondition,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Badge de force
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: strengthColor(context).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: strengthColor(context)),
                  ),
                  child: Text(
                    strength,
                    style: TextStyle(
                      color: strengthColor(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Corrélation brute
            _buildInfoRow(
              context,
              icon: Icons.analytics_outlined,
              label: 'Observation',
              value: '$daysWithSymptoms jours avec $symptomLabel sur $daysWithCondition jours ${_getConditionText()} (${correlationPercentage.toStringAsFixed(1)}%)',
            ),

            const Divider(height: 24),

            // Baseline comparative
            _buildInfoRow(
              context,
              icon: Icons.show_chart,
              label: 'Taux habituel',
              value: '$symptomLabelPossessif ${symptomType == 'Fatigue' ? 'apparaît' : 'apparaissent'} ${baselinePercentage.toStringAsFixed(1)}% du temps',
            ),

            const Divider(height: 24),

            // Delta & signification
            Row(
              children: [
                Icon(
                  delta > 0 ? Icons.trending_up : Icons.trending_down,
                  color: delta > 0 ? Colors.red : Colors.green,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getSignification(symptomLabel, symptomLabelPossessif),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Badge de fiabilité
            Row(
              children: [
                Icon(
                  Icons.fact_check_outlined,
                  size: 16,
                  color: reliabilityColor(context),
                ),
                const SizedBox(width: 6),
                Text(
                  'Fiabilité : $reliability',
                  style: TextStyle(
                    color: reliabilityColor(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '($daysWithCondition jours analysés)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, {required IconData icon, required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getConditionText() {
    if (weatherCondition.contains('Froid')) return 'froids';
    if (weatherCondition.contains('Chaud')) return 'chauds';
    if (weatherCondition.contains('Humidité')) return 'humides';
    if (weatherCondition.contains('pression')) return 'à basse pression';
    if (weatherCondition.contains('Pluie')) return 'pluvieux';
    return 'exposés';
  }

  String _getSignification(String symptomLabel, String symptomLabelPossessif) {
    if (daysWithCondition < 3) {
      return 'Pas assez de données pour tirer une conclusion fiable.';
    }

    if (delta.abs() < 10) {
      return 'Aucun lien apparent : $symptomLabelPossessif ${symptomType == 'Fatigue' ? 'semble indépendante' : 'semblent indépendants'} de cette condition météo.';
    }

    if (delta > 0) {
      // Corrélation positive
      if (strength == 'Forte') {
        return '⚠️ Forte corrélation : $symptomLabelPossessif ${symptomType == 'Fatigue' ? 'apparaît' : 'apparaissent'} beaucoup plus souvent durant ${_getConditionText()}.';
      } else if (strength == 'Modérée') {
        return 'Corrélation modérée : $symptomLabelPossessif ${symptomType == 'Fatigue' ? 'semble' : 'semblent'} plus ${symptomType == 'Fatigue' ? 'fréquente' : 'fréquents'} durant ${_getConditionText()}.';
      } else {
        return 'Faible tendance : légère augmentation ${symptomType == 'Fatigue' ? 'de la fatigue' : 'des $symptomLabel'} durant ${_getConditionText()}.';
      }
    } else {
      // Corrélation négative (protectrice)
      if (strength == 'Forte') {
        return '✓ Fort effet protecteur : $symptomLabelPossessif ${symptomType == 'Fatigue' ? 'est' : 'sont'} beaucoup moins ${symptomType == 'Fatigue' ? 'fréquente' : 'fréquents'} durant ${_getConditionText()}.';
      } else if (strength == 'Modérée') {
        return 'Effet protecteur modéré : $symptomLabelPossessif ${symptomType == 'Fatigue' ? 'semble' : 'semblent'} moins ${symptomType == 'Fatigue' ? 'fréquente' : 'fréquents'} durant ${_getConditionText()}.';
      } else {
        return 'Faible tendance protectrice : légère diminution ${symptomType == 'Fatigue' ? 'de la fatigue' : 'des $symptomLabel'} durant ${_getConditionText()}.';
      }
    }
  }

  IconData _getWeatherIcon() {
    if (weatherCondition.contains('Froid')) return Icons.ac_unit;
    if (weatherCondition.contains('Chaud')) return Icons.wb_sunny;
    if (weatherCondition.contains('Humidité')) return Icons.water_drop;
    if (weatherCondition.contains('pression')) return Icons.speed;
    if (weatherCondition.contains('Pluie')) return Icons.cloud;
    return Icons.wb_cloudy;
  }
}
