import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
import '../database_helper.dart';
import '../services/training_service.dart';
import '../symptom_taxonomy.dart';

class ModelStatusPage extends StatefulWidget {
  const ModelStatusPage({super.key});

  @override
  State<ModelStatusPage> createState() => _ModelStatusPageState();
}

class _ModelStatusPageState extends State<ModelStatusPage> {
  bool _isLoading = true;
  TrainingDataStatus? _dataStatus;
  List<Map<String, dynamic>> _trainingHistory = [];
  Map<String, Map<String, dynamic>> _statusByType = {};

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final trainingService = TrainingService();
    final dbHelper = DatabaseHelper();

    final status = await trainingService.checkDataAvailability();
    final history = await dbHelper.getLatestTrainingHistory(limit: 5);
    final byType = await dbHelper.checkTrainingDataByType();

    if (mounted) {
      setState(() {
        _dataStatus = status;
        _trainingHistory = history;
        _statusByType = byType;
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshStatus() async {
    setState(() => _isLoading = true);
    await _loadStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryStart.withValues(alpha: 0.9),
                AppColors.primaryEnd.withValues(alpha: 0.8),
              ],
            ),
          ),
        ),
        title: Text(
          'Statut des Modèles ML',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshStatus,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildCorrelationExplanationCard(),
                const SizedBox(height: 16),
                _buildDataAvailabilityCard(),
                const SizedBox(height: 16),
                _buildModelsStatusCard(),
                const SizedBox(height: 16),
                _buildTrainingHistoryCard(),
              ],
            ),
    );
  }

  Widget _buildDataAvailabilityCard() {
    final status = _dataStatus!;
    final progress = (status.mealCount / 30).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.data_usage, color: AppColors.primaryStart),
                const SizedBox(width: 8),
                Text(
                  'Données Disponibles',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Progress bar
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(
                status.hasEnoughData ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              status.message,
              style: TextStyle(
                color: status.hasEnoughData ? Colors.green : Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),

            // Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  '${status.mealCount}',
                  'Repas',
                  Icons.restaurant,
                  Colors.orange,
                ),
                _buildStatItem(
                  '${status.symptomCount}',
                  'Symptômes',
                  Icons.bolt,
                  Colors.red,
                ),
                _buildStatItem(
                  status.hasEnoughData ? 'Prêt' : 'Incomplet',
                  'Statut',
                  status.hasEnoughData ? Icons.check_circle : Icons.pending,
                  status.hasEnoughData ? Colors.green : Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildModelsStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.model_training, color: AppColors.primaryStart),
                const SizedBox(width: 8),
                Text(
                  'Modèles de Prédiction',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Use dynamic taxonomy instead of hardcoded models
            ...SymptomTaxonomy.models.map((config) {
              final modelStatus = _statusByType[config.modelKey] ?? {};
              final symptomCount = modelStatus['symptom_count'] ?? 0;
              final correlationCount = modelStatus['correlation_count'] ?? 0;
              final isReady = modelStatus['is_ready'] ?? false;

              // Find training history for this model
              final history = _trainingHistory
                  .where((h) => (h['model_name'] as String) == config.modelKey)
                  .toList();

              final trained = history.isNotEmpty;
              final f1Score = trained
                  ? history.first['f1_score'] as double
                  : 0.0;
              final trainedAt = trained
                  ? DateTime.parse(history.first['trained_at'] as String)
                  : null;

              return _buildModelExpansionTile(
                config,
                symptomCount,
                correlationCount,
                isReady,
                trained,
                f1Score,
                trainedAt,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildModelExpansionTile(
    SymptomModelConfig config,
    int symptomCount,
    int correlationCount,
    bool isReady,
    bool trained,
    double f1Score,
    DateTime? trainedAt,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Text(config.icon, style: const TextStyle(fontSize: 24)),
        title: Text(
          config.displayName,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          trained
              ? 'Entraîné • F1: ${(f1Score * 100).toStringAsFixed(0)}%'
              : (isReady ? 'Prêt pour entraînement' : 'Données insuffisantes'),
          style: TextStyle(
            color: trained
                ? Colors.green
                : (isReady ? Colors.orange : Colors.grey),
          ),
        ),
        trailing: Icon(
          trained
              ? Icons.check_circle
              : (isReady ? Icons.pending : Icons.cancel),
          color: trained
              ? Colors.green
              : (isReady ? Colors.orange : Colors.grey),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.description,
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                ),
                const SizedBox(height: 12),

                // Data status
                _buildDataStatusRow(
                  'Symptômes (${config.sourceTags.join(", ")})',
                  '$symptomCount',
                  Icons.bolt,
                ),
                const SizedBox(height: 8),
                _buildDataStatusRow(
                  'Corrélations (4-8h)',
                  '$correlationCount',
                  Icons.link,
                ),
                const SizedBox(height: 8),
                _buildDataStatusRow(
                  'Minimum requis',
                  '${config.minSamples} paires',
                  Icons.info_outline,
                ),

                if (trained && trainedAt != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Dernière mise à jour: ${_formatDate(trainedAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],

                if (!isReady) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Enregistrez plus de repas et symptômes pour activer ce modèle',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataStatusRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return "Aujourd'hui à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } else if (diff.inDays == 1) {
      return "Hier à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } else if (diff.inDays < 7) {
      return "Il y a ${diff.inDays} jours";
    } else {
      return "${date.day}/${date.month}/${date.year}";
    }
  }

  Widget _buildCorrelationExplanationCard() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Comment ça marche ?',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Les modèles ML analysent la fenêtre temporelle de 4 à 8 heures après chaque repas pour détecter les corrélations meal-symptôme.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue[900],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '• Enregistrez vos repas et symptômes régulièrement\n'
              '• L\'app détecte automatiquement les aliments à risque\n'
              '• Plus de données = prédictions plus précises\n'
              '• Minimum 30 paires repas-symptôme par type',
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue[800],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrainingHistoryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: AppColors.primaryStart),
                const SizedBox(width: 8),
                Text(
                  'Historique d\'Entraînement',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_trainingHistory.isEmpty)
              Center(
                child: Text(
                  'Aucun entraînement effectué',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              )
            else
              ..._trainingHistory.map((entry) {
                final date = DateTime.parse(entry['trained_at'] as String);
                final modelName = entry['model_name'] as String;
                final f1 = entry['f1_score'] as double;
                final accuracy = entry['accuracy'] as double;

                return ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.check_circle,
                    color: f1 > 0.7 ? Colors.green : Colors.orange,
                  ),
                  title: Text(
                    modelName.replaceAll('_predictor', ''),
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    'F1: ${(f1 * 100).toStringAsFixed(1)}% • Précision: ${(accuracy * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Text(
                    '${date.day}/${date.month}/${date.year}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
