import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'logs_page.dart';
import 'ml/model_status_page.dart';
import 'methodology_page.dart';
import 'database_helper.dart';
import 'services/training_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Paramètres & Outils',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        children: [
          _buildSectionHeader('Maintenance'),
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
          
          _buildSectionHeader('Développeur'),
          _buildSettingsTile(
            context,
            icon: Icons.delete_forever,
            title: 'Réinitialiser la base',
            subtitle: 'Attention : Action irréversible',
            color: Colors.red,
            onTap: () => _showClearDatabaseDialog(context),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.restore,
            title: 'Générer Données Démo',
            subtitle: 'Ajoute 30 jours de données fictives',
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
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
    Color color = AppColors.textPrimary,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: color)),
      subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
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
       builder: (context) => AlertDialog(
         title: const Text('🎲 Générer Démo'),
         content: const Text('Ceci va générer 30 jours d\'historique fictif.'),
         actions: [
           TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
           TextButton(
             onPressed: () async {
               Navigator.pop(context);
               await DatabaseHelper().generateDemoData();
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
}
