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
          
          _buildSectionHeader(context, 'Sécurité & Confidentialité'),
          FutureBuilder<bool>(
            future: DatabaseHelper().isEncryptionEnabled(),
            builder: (context, snapshot) {
              final isEncrypted = snapshot.data ?? false;
              return SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                secondary: Icon(
                  isEncrypted ? Icons.lock : Icons.lock_open,
                  color: isEncrypted ? Colors.green : Colors.orange,
                ),
                title: Text(
                  'Chiffrement de la base',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                subtitle: Text(
                  isEncrypted
                      ? '🔒 Activé - Vos données sont chiffrées AES-256'
                      : '⚠️ Désactivé - Données en clair (non recommandé)',
                  style: TextStyle(
                    color: isEncrypted 
                        ? Theme.of(context).colorScheme.onSurface
                        : Colors.orange,
                  ),
                ),
                value: isEncrypted,
                onChanged: (value) {
                  if (value) {
                    _showEnableEncryptionDialog(context);
                  } else {
                    _showDisableEncryptionDialog(context);
                  }
                },
              );
            },
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
            subtitle: 'Supprime toutes les données (IRRÉVERSIBLE)',
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
    Widget? trailing,
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
      subtitle: Text(subtitle),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _showClearDatabaseDialog(BuildContext context) {
    bool deleteEncryptionKeys = false;
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.delete_forever, color: Colors.red),
              SizedBox(width: 8),
              Text('⚠️ Réinitialiser la base'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ceci va supprimer TOUTES les données :',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Tous vos repas, symptômes, selles'),
              const Text('• Historique météo et corrélations'),
              const Text('• Modèles ML entraînés'),
              const Text('• Cache de la base aliments'),
              const SizedBox(height: 16),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '🔐 Supprimer aussi les clés de chiffrement',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Si décoché : vos données sont supprimées MAIS vous pourrez\n'
                  're-chiffrer de futures données avec la même clé.\n\n'
                  'Si coché (RGPD total) : clé détruite, impossible de\n'
                  'déchiffrer d\'anciennes sauvegardes chiffrées.',
                  style: TextStyle(fontSize: 11),
                ),
                value: deleteEncryptionKeys,
                onChanged: (value) {
                  setState(() => deleteEncryptionKeys = value ?? false);
                },
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '⚠️ Action IRRÉVERSIBLE',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              icon: const Icon(Icons.delete_forever),
              label: const Text('RÉINITIALISER'),
              onPressed: () async {
                Navigator.pop(dialogContext);
                
                // Show loading dialog
                if (!context.mounted) return;
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const Center(child: CircularProgressIndicator()),
                );

                // CRITIQUE: Capturer Navigator et ScaffoldMessenger AVANT le await
                // car le context sera démonté après l'opération longue
                final navigator = Navigator.of(context);
                final scaffold = ScaffoldMessenger.of(context);

                try {
                  debugPrint('[SETTINGS] Début réinitialisation...');
                  if (deleteEncryptionKeys) {
                    await DatabaseHelper().deleteAllDataPermanently();
                  } else {
                    final dbHelper = DatabaseHelper();
                    final db = await dbHelper.database;
                    await db.delete('events');
                    await db.delete('foods');
                    await db.delete('products_cache');
                    await db.delete('correlation_cache');
                    await db.delete('macro_thresholds');
                    await db.delete('ml_feedback');
                  }
                  
                  debugPrint('[SETTINGS] Suppression terminée');
                  
                  // Utiliser les objets capturés (fonctionnent même si context démonté)
                  navigator.pop(); // Fermer loading dialog
                  debugPrint('[SETTINGS] Dialog fermé');
                  
                  scaffold.showSnackBar(
                    SnackBar(
                      content: Text(
                        deleteEncryptionKeys
                            ? '✅ Base effacée (RGPD). Redémarrage...'
                            : '✅ Base réinitialisée. Redémarrage...',
                      ),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  
                  await Future.delayed(const Duration(milliseconds: 500));
                  
                  debugPrint('[SETTINGS] Redémarrage navigation...');
                  navigator.pushNamedAndRemoveUntil('/', (route) => false);
                  
                } catch (e, stackTrace) {
                  debugPrint('[SETTINGS] ❌ Erreur: $e');
                  debugPrint('[SETTINGS] Stack: $stackTrace');
                  
                  navigator.pop(); // Close loading dialog
                  scaffold.showSnackBar(
                    SnackBar(
                      content: Text('❌ Erreur: $e'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              },
            ),
          ],
        ),
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

  void _showEnableEncryptionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock, color: Colors.green),
            SizedBox(width: 8),
            Text('Activer le chiffrement'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cette opération va :',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Chiffrer toutes vos données avec AES-256'),
            Text('• Générer une clé stockée de manière sécurisée'),
            Text('• Migrer automatiquement vos données existantes'),
            SizedBox(height: 16),
            Text(
              '⚠️ L\'app va redémarrer après l\'opération.',
              style: TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.lock),
            label: const Text('ACTIVER'),
            onPressed: () async {
              Navigator.pop(dialogContext);
              
              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              final result = await DatabaseHelper().enableEncryption();
              
              if (!context.mounted) return;
              Navigator.pop(context); // Close loading

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result.message),
                  backgroundColor: result.success ? Colors.green : Colors.red,
                  duration: const Duration(seconds: 4),
                ),
              );

              if (result.success) {
                // Refresh UI
                (context as Element).markNeedsBuild();
              }
            },
          ),
        ],
      ),
    );
  }

  void _showDisableEncryptionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_open, color: Colors.orange),
            SizedBox(width: 8),
            Text('Désactiver le chiffrement'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⚠️ ATTENTION',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
            ),
            SizedBox(height: 8),
            Text('Vos données seront stockées EN CLAIR sur l\'appareil.'),
            Text('Toute personne ayant accès au fichier pourra les lire.'),
            SizedBox(height: 16),
            Text('Seulement recommandé pour le développement.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.lock_open),
            label: const Text('DÉSACTIVER'),
            onPressed: () async {
              Navigator.pop(dialogContext);
              
              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              final result = await DatabaseHelper().disableEncryption();
              
              if (!context.mounted) return;
              Navigator.pop(context); // Close loading

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result.message),
                  backgroundColor: result.success ? Colors.green : Colors.red,
                  duration: const Duration(seconds: 4),
                ),
              );

              if (result.success) {
                // Refresh UI
                (context as Element).markNeedsBuild();
              }
            },
          ),
        ],
      ),
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
