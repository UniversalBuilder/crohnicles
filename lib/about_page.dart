import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'À propos',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Icon + Title
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.health_and_safety,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Crohnicles',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Version 1.0.0',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Description
            _buildSection(
              context,
              icon: Icons.info_outline,
              title: 'Description',
              content: 'Crohnicles est un journal de santé intelligent pour les personnes atteintes de maladies inflammatoires chroniques de l\'intestin (MICI). '
                  'Il vous aide à suivre vos repas, symptômes et selles, puis analyse statistiquement vos données pour identifier des corrélations personnalisées entre alimentation et symptômes.',
            ),
            const SizedBox(height: 24),
            
            // Author
            _buildSection(
              context,
              icon: Icons.person,
              title: 'Auteur',
              content: 'Développé avec ❤️ par Yannick KREMPP\n\n'
                  'Projet personnel créé pour gérer ma propre maladie de Crohn. Mon objectif est de fournir un outil gratuit, open source et respectueux de la vie privée à la communauté des personnes atteintes de MICI.',
            ),
            const SizedBox(height: 24),
            
            // License
            _buildSection(
              context,
              icon: Icons.gavel,
              title: 'License',
              content: 'Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0)\n\n'
                  '✅ Utilisation personnelle gratuite\n'
                  '✅ Modification et redistribution autorisées\n'
                  '🚫 Usage commercial interdit\n'
                  '⚠️ Attribution obligatoire',
            ),
            const SizedBox(height: 24),
            
            // Privacy
            _buildSection(
              context,
              icon: Icons.privacy_tip,
              title: 'Confidentialité',
              content: '🔒 Vos données ne quittent JAMAIS votre appareil (sauf backup cloud optionnel)\n'
                  '🔒 Calcul 100% local (aucun serveur tiers)\n'
                  '🔒 Aucune donnée personnelle collectée\n'
                  '🔒 Code source auditable (open source)',
            ),
            const SizedBox(height: 24),
            
            // Medical Disclaimer
            _buildSection(
              context,
              icon: Icons.warning_amber,
              title: 'Avertissement Médical',
              content: '⚠️ CROHNICLES N\'EST PAS UN DISPOSITIF MÉDICAL CERTIFIÉ\n\n'
                  '❌ Ne jamais modifier un traitement sur la base des prédictions\n'
                  '❌ Ne jamais remplacer l\'avis d\'un gastro-entérologue\n'
                  '✅ Toujours consulter un professionnel de santé\n\n'
                  'Les corrélations identifiées sont personnelles et non généralisables.',
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 32),
            
            // Donation Section
            _buildDonationSection(context),
            const SizedBox(height: 32),
            
            // Links
            _buildLinksSection(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
    Color? color,
  }) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: effectiveColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: effectiveColor, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: effectiveColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.favorite,
                color: Theme.of(context).colorScheme.error,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Soutenir le Projet',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Crohnicles est et restera gratuit. Si l\'application vous est utile, vous pouvez soutenir le développement par un don volontaire. '
            'Cela m\'aide à maintenir le projet, ajouter de nouvelles fonctionnalités et couvrir les frais d\'infrastructure.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
          
          // Donation Buttons
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildDonationButton(
                context,
                icon: Icons.payment,
                label: 'PayPal',
                color: const Color(0xFF0070BA),
                onTap: () => _launchUrl('https://paypal.me/YOUR_PAYPAL'),
              ),
              _buildDonationButton(
                context,
                icon: Icons.coffee,
                label: 'Ko-fi',
                color: const Color(0xFFFF5E5B),
                onTap: () => _launchUrl('https://ko-fi.com/YOUR_KOFI'),
              ),
              _buildDonationButton(
                context,
                icon: Icons.code,
                label: 'GitHub Sponsors',
                color: const Color(0xFFEA4AAA),
                onTap: () => _launchUrl('https://github.com/sponsors/YOUR_GITHUB'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '💚 Autres façons de soutenir :\n'
            '⭐ Star sur GitHub\n'
            '📢 Partager avec d\'autres personnes MICI\n'
            '🐛 Signaler des bugs\n'
            '💡 Proposer des fonctionnalités',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinksSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'LIENS UTILES',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1.0,
            ),
          ),
        ),
        _buildLinkTile(
          context,
          icon: Icons.code,
          title: 'Code Source (GitHub)',
          url: 'https://github.com/YOUR_USERNAME/crohnicles',
        ),
        _buildLinkTile(
          context,
          icon: Icons.bug_report,
          title: 'Signaler un Bug',
          url: 'https://github.com/YOUR_USERNAME/crohnicles/issues',
        ),
        _buildLinkTile(
          context,
          icon: Icons.forum,
          title: 'Discussions',
          url: 'https://github.com/YOUR_USERNAME/crohnicles/discussions',
        ),
        _buildLinkTile(
          context,
          icon: Icons.description,
          title: 'Documentation',
          url: 'https://github.com/YOUR_USERNAME/crohnicles#readme',
        ),
        _buildLinkTile(
          context,
          icon: Icons.article,
          title: 'License Complète',
          onTap: () => _showLicenseDialog(context),
        ),
      ],
    );
  }

  Widget _buildLinkTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? url,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      trailing: Icon(
        Icons.open_in_new,
        size: 16,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onTap: url != null ? () => _launchUrl(url) : onTap,
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showLicenseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('License CC BY-NC-SA 4.0'),
        content: SingleChildScrollView(
          child: Text(
            'Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International\n\n'
            'Copyright (c) 2024-2025 Yannick KREMPP\n\n'
            'Vous êtes autorisé à :\n\n'
            '✅ Partager — copier et redistribuer le matériel\n'
            '✅ Adapter — remixer, transformer et créer\n\n'
            'Selon les conditions suivantes :\n\n'
            '⚠️ Attribution — Créditer l\'œuvre originale\n'
            '🚫 Pas d\'Utilisation Commerciale\n'
            '🔄 Partage dans les Mêmes Conditions\n\n'
            'Texte complet : https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode.fr',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(
                const ClipboardData(
                  text: 'https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode.fr',
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Lien copié !')),
              );
            },
            child: const Text('Copier le lien'),
          ),
        ],
      ),
    );
  }
}
