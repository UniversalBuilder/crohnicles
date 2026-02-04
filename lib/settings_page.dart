import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'logs_page.dart';
import 'ml/model_status_page.dart';
import 'ml/training_service.dart';
import 'methodology_page.dart';
import 'about_page.dart';
import 'database_helper.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Paramètres & Outils',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      body: ListView(
        children: [
          // Theme Mode Selector
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              'Mode d\'affichage',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) {
                  return SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode),
                        label: Text('Clair'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto),
                        label: Text('Auto'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode),
                        label: Text('Sombre'),
                      ),
                    ],
                    selected: {themeProvider.themeMode},
                    onSelectionChanged: (Set<ThemeMode> newSelection) {
                      themeProvider.setThemeMode(newSelection.first);
                    },
                  );
                },
              ),
            ),
          ),
          const Divider(height: 32),
          
          _buildSectionHeader(context, 'Informations'),
          _buildSettingsTile(
            context,
            icon: Icons.info_outline,
            title: 'À propos de Crohnicles',
            subtitle: 'Auteur, licence, dons et confidentialité',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutPage())),
          ),
          
          _buildSectionHeader(context, 'Maintenance'),
          _buildSettingsTile(
            context,
            icon: Icons.terminal,
            title: 'Logs Système',
            subtitle: 'Voir les journaux d\'erreurs et d\'activité',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LogsPage())),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.model_training,
            title: 'Statut ML & IA',
            subtitle: 'État des modèles et des données',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ModelStatusPage())),
          ),
           _buildSettingsTile(
            context,
            icon: Icons.science,
            title: 'Méthodologie',
            subtitle: 'Comprendre comment l\'IA fonctionne',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MethodologyPage())),
          ),
          
          _buildSectionHeader(context, 'Développeur'),
          _buildSettingsTile(
            context,
            icon: Icons.psychology,
            title: '🧠 Entraîner Modèle ML',
            subtitle: 'Améliore les prédictions avec tes données',
            onTap: () => _showTrainMLDialog(context),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.delete_forever,
            title: 'Réinitialiser la base',
            subtitle: 'Attention : Action irréversible',
            color: Theme.of(context).colorScheme.error,
            onTap: () => _showClearDatabaseDialog(context),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.restore,
            title: 'Générer Données Démo',
            subtitle: 'Ajoute 100 jours de données fictives réalistes',
            onTap: () => _showGenerateDemoDialog(context),
          ),
           _buildSettingsTile(
            context,
            icon: Icons.cloud_download,
            title: 'Enrichir Base Aliments',
            subtitle: 'Télécharge des produits OpenFoodFacts',
            onTap: () => _enrichWithOFFProducts(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.onSurface;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: effectiveColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: effectiveColor),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: effectiveColor)),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: Icon(Icons.chevron_right, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
      onTap: onTap,
    );
  }

  void _showClearDatabaseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Effacer la base'),
        content: const Text(
          'Ceci va supprimer TOUTES les données.\nAction IRRÉVERSIBLE !',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await DatabaseHelper().database.then((db) async {
                 await db.delete('events');
                 await db.delete('foods');
                 await db.delete('products_cache');
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Base de données effacée')),
              );
            },
            child: const Text('EFFACER TOUT'),
          ),
        ],
      ),
    );
  }

  void _showGenerateDemoDialog(BuildContext context) {
    showDialog(
       context: context,
       builder: (dialogContext) => AlertDialog(
         title: const Text('🎲 Générer Démo'),
         content: const Text('Ceci va générer 100 jours d\'historique fictif avec météo et corrélations réalistes.'),
         actions: [
           TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
           TextButton(
             onPressed: () async {
               Navigator.pop(dialogContext);
               await DatabaseHelper().generateDemoData();
               if (!context.mounted) return;
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('✅ Données générées')),
               );
             },
             child: const Text('GÉNÉRER'),
           ),
         ],
       ),
     );
  }

  void _enrichWithOFFProducts(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Téléchargement en cours...')),
    );
    await DatabaseHelper().enrichWithPopularOFFProducts();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Base enrichie')),
    );
  }

  void _showTrainMLDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismiss during training
      builder: (dialogContext) => TrainMLDialog(),
    );
  }
}

/// Dialog for ML model training with progress
class TrainMLDialog extends StatefulWidget {
  const TrainMLDialog({super.key});

  @override
  State<TrainMLDialog> createState() => _TrainMLDialogState();
}

class _TrainMLDialogState extends State<TrainMLDialog> {
  bool _isTraining = false;
  String _currentStep = 'Initialisation...';
  TrainingResult? _result;

  @override
  void initState() {
    super.initState();
    _startTraining();
  }

  Future<void> _startTraining() async {
    setState(() {
      _isTraining = true;
      _currentStep = 'Démarrage...';
    });

    final trainingService = TrainingService();
    
    try {
      final result = await trainingService.trainAllModels(
        windowHours: 8,
        onProgress: (step) {
          if (!mounted) return;
          setState(() {
            _currentStep = step;
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _isTraining = false;
        _result = result;
      });

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTraining = false;
        _result = TrainingResult(
          success: false,
          modelMetrics: {},
          errorMessage: e.toString(),
          trainedAt: DateTime.now(),
          trainingDataSize: 0,
          trainingDuration: Duration.zero,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.psychology, color: colorScheme.primary),
          const SizedBox(width: 12),
          const Text('Entraînement ML'),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isTraining) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                _currentStep,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Cela peut prendre 1-3 minutes...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ] else if (_result != null) ...[
              if (_result!.success) ...[
                Icon(Icons.check_circle, size: 64, color: Colors.green),
                const SizedBox(height: 16),
                Text(
                  'Entraînement terminé !',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Durée: ${_result!.trainingDuration.inSeconds}s',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Divider(height: 32),
                Text(
                  'Résultats:',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ..._result!.modelMetrics.entries.map((entry) {
                  final metrics = entry.value;
                  final accuracy = (metrics.accuracy * 100).toStringAsFixed(1);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key),
                        Chip(
                          label: Text('$accuracy%'),
                          backgroundColor: metrics.accuracy >= 0.7
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.orange.withValues(alpha: 0.2),
                        ),
                      ],
                    ),
                  );
                }),
              ] else ...[
                Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Échec de l\'entraînement',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _result!.errorMessage ?? 'Erreur inconnue',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        if (!_isTraining)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_result?.success == true ? 'OK' : 'Fermer'),
          ),
      ],
    );
  }
}
