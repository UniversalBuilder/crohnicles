import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';

/// Card affichant le statut d'entraînement du modèle ML
/// - Nombre de repas/symptômes collectés
/// - Progression vers le seuil de 30 pour chaque
/// - Dernière date d'entraînement
/// - État de préparation du modèle
class MLTrainingStatusCard extends StatefulWidget {
  const MLTrainingStatusCard({super.key});

  @override
  State<MLTrainingStatusCard> createState() => _MLTrainingStatusCardState();
}

class _MLTrainingStatusCardState extends State<MLTrainingStatusCard> {
  bool _isLoading = true;
  int _mealCount = 0;
  int _symptomCount = 0;
  String? _lastTrainingDate;
  int _trainingCount = 0;
  bool _isReady = false;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final db = DatabaseHelper();
      final stats = await db.getMLTrainingStats();
      
      setState(() {
        _mealCount = stats['mealCount'] as int;
        _symptomCount = stats['symptomCount'] as int;
        _lastTrainingDate = stats['lastTrainingDate'] as String?;
        _trainingCount = stats['trainingCount'] as int;
        _isReady = stats['isReady'] as bool;
        _progress = stats['progress'] as double;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[ML_STATUS] Erreur de chargement: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        margin: EdgeInsets.all(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Couleur de statut selon la disponibilité du modèle
    final statusColor = _isReady 
        ? Colors.green 
        : (_progress > 0.5 ? Colors.orange : Colors.grey);

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 0,
      color: isDark ? Colors.grey[850] : colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: statusColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header avec icône et titre
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _isReady ? Icons.check_circle : Icons.timer,
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Entraînement du Modèle IA',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _isReady 
                            ? 'Modèle prêt à analyser vos données'
                            : 'Collecte de données en cours...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Barre de progression globale
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progression globale',
                      style: theme.textTheme.bodyMedium,
                    ),
                    Text(
                      '${(_progress * 100).toInt()}%',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 12,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Détails: Repas et Symptômes
            Row(
              children: [
                Expanded(
                  child: _buildDataCounter(
                    context,
                    'Repas',
                    _mealCount,
                    30,
                    Icons.restaurant,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDataCounter(
                    context,
                    'Symptômes',
                    _symptomCount,
                    30,
                    Icons.warning_amber,
                    Colors.red,
                  ),
                ),
              ],
            ),

            // Dernière date d'entraînement (si existe)
            if (_lastTrainingDate != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.history,
                    size: 20,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Dernier entraînement : ${_formatDate(_lastTrainingDate!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.bar_chart,
                    size: 20,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$_trainingCount entraînement${_trainingCount > 1 ? 's' : ''} effectué${_trainingCount > 1 ? 's' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],

            // Message d'aide si pas assez de données
            if (!_isReady) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Colors.orange[700],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Continuez à enregistrer vos repas et symptômes pour activer les prédictions IA.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.orange[200] : Colors.orange[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDataCounter(
    BuildContext context,
    String label,
    int current,
    int target,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isComplete = current >= target;
    final percentage = (current / target).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: isComplete ? 0.5 : 0.2),
          width: isComplete ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$current',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                ' / $target',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) {
        return "aujourd'hui à ${DateFormat.Hm().format(date)}";
      } else if (diff.inDays == 1) {
        return 'hier';
      } else if (diff.inDays < 7) {
        return 'il y a ${diff.inDays} jours';
      } else {
        return DateFormat('dd/MM/yyyy').format(date);
      }
    } catch (e) {
      return isoDate;
    }
  }
}
