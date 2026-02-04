import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MethodologyPage extends StatelessWidget {
  const MethodologyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Comment ça marche ?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('📊 Deux Moteurs d\'Analyse Complémentaires', context),
            _buildSectionText(
              context,
              "Crohnicles utilise DEUX systèmes d'analyse qui fonctionnent en parallèle. Tout est calculé localement sur votre appareil pour garantir votre confidentialité.",
            ),
            const SizedBox(height: 16),

            _buildComparisonTable(context),
            const SizedBox(height: 24),

            _buildCard(
              context: context,
              title: "1️⃣ Moteur Statistique (📊 Stats)",
              icon: Icons.bar_chart,
              color: Colors.blue,
              content: """
TOUJOURS ACTIF dès que vous avez assez de données (30 repas + 10 symptômes).

Comment ça marche :
• Calcule les corrélations fréquentielles entre aliments et symptômes
• Fenêtre d'analyse : 4-8h après le repas
• Formule : P(Symptôme | Aliment) = nb_symptômes_après / nb_occurrences_aliment

Avantages :
✓ Rapide et transparent
✓ Fonctionne automatiquement
✓ Détecte les corrélations évidentes

Limites :
✗ Analyse simple (une seule variable à la fois)
✗ Ne détecte pas les interactions complexes

Quand : Utilisé PAR DÉFAUT dans tous les écrans d'analyse.
              """,
            ),
            const SizedBox(height: 16),

            _buildCard(
              context: context,
              title: "2️⃣ Machine Learning (🧠 ML)",
              icon: Icons.psychology,
              color: Colors.purple,
              content: """
OPTIONNEL - Nécessite entraînement manuel via le bouton 🧠 dans Paramètres.

Comment ça marche :
• Apprentissage supervisé sur vos données historiques (90 jours)
• Analyse multi-variables avec tag scoring
• Modèles personnalisés par type de symptôme (douleur, diarrhée, ballonnements...)

Avantages :
✓ Détecte patterns complexes (combinaisons d'aliments)
✓ S'améliore avec le temps
✓ Prédictions plus précises

Limites :
✗ Nécessite BEAUCOUP de données (90+ jours, 30+ repas, 20+ symptômes)
✗ Entraînement manuel requis
✗ "Boîte noire" (moins transparent)

Quand : Activé après entraînement, utilisé EN COMPLÉMENT des stats simples.
              """,
            ),
            const SizedBox(height: 16),

            _buildCard(
              context: context,
              title: "🔄 Comment les Utiliser Ensemble",
              icon: Icons.compare_arrows,
              color: Colors.green,
              content: """
WORKFLOW RECOMMANDÉ :

Phase 1 - Démarrage (J0-30) :
→ Stats temps réel avec historique limité
→ Confiance limitée (max 30%)

Phase 2 - Analyse Mature (J30+) :
→ Stats automatiques fiables
→ Badges "📊 Stats" dans l'app

Phase 3 - ML Avancé (J90+, optionnel) :
→ Entraîner modèle via bouton 🧠 dans Paramètres
→ Prédictions combinées Stats + ML
→ Badges "🧠 ML" pour prédictions avancées

TRANSPARENCE : Partout dans l'app, les sources sont indiquées par des badges pour que vous sachiez d'où viennent les informations.
              """,
            ),

            const SizedBox(height: 24),
            _buildSectionTitle('🔍 Confidentialité', context),
            _buildSectionText(
              context,
              "Vos données ne quittent jamais votre appareil (sauf si vous activez la sauvegarde cloud). L'analyse est effectuée localement pour garantir votre confidentialité totale.",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonTable(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Table(
        border: TableBorder.symmetric(
          inside: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
        ),
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(3),
          2: FlexColumnWidth(3),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            ),
            children: [
              _buildTableCell(context, '', isHeader: true),
              _buildTableCell(context, '📊 Stats', isHeader: true),
              _buildTableCell(context, '🧠 ML', isHeader: true),
            ],
          ),
          _buildTableRow(context, 'Activation', 'Automatique', 'Manuelle'),
          _buildTableRow(context, 'Données min.', '30 repas', '90 jours'),
          _buildTableRow(context, 'Détection', 'Corrélations simples', 'Patterns complexes'),
          _buildTableRow(context, 'Transparence', 'Haute', 'Moyenne'),
          _buildTableRow(context, 'Précision', 'Bonne', 'Excellente'),
        ],
      ),
    );
  }

  TableRow _buildTableRow(BuildContext context, String label, String stats, String ml) {
    return TableRow(
      children: [
        _buildTableCell(context, label, isBold: true),
        _buildTableCell(context, stats),
        _buildTableCell(context, ml),
      ],
    );
  }

  Widget _buildTableCell(BuildContext context, String text, {bool isHeader = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: isHeader || isBold ? FontWeight.bold : FontWeight.normal,
          color: isHeader 
            ? Theme.of(context).colorScheme.onPrimaryContainer 
            : Theme.of(context).colorScheme.onSurface,
        ),
        textAlign: isHeader ? TextAlign.center : TextAlign.left,
      ),
    );
  }

  Widget _buildSectionTitle(String title, BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _buildSectionText(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required String content,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
