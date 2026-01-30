import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MethodologyPage extends StatelessWidget {
  const MethodologyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFC),
      appBar: AppBar(
        title: Text(
          'Comment ça marche ?',
          style: GoogleFonts.manrope(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('🤖 Modèles Hybrides'),
            _buildSectionText(
              "Crohnicles utilise une approche hybride pour estimer les risques de vos repas. L'objectif est de vous fournir des informations pertinentes même sans connexion internet.",
            ),
            const SizedBox(height: 24),
            
            _buildCard(
              title: "1. Moteur Statistique (Mobile)",
              icon: Icons.bar_chart,
              color: Colors.blue,
              content: """
Sur votre téléphone, l'application analyse directement votre historique :

• Elle regarde tous les repas contenant un ingrédient spécifique (ex: "Gluten").
• Elle compte combien de fois un symptôme est apparu dans les 24h qui ont suivi.
• Si ce taux dépasse 30%, une "corrélation" est détectée.

Exemple : Si vous avez mangé 10 fois du gluten et eu 4 fois des douleurs, le risque calculé sera de 40%.
              """,
            ),
             const SizedBox(height: 16),

            _buildCard(
              title: "2. Règles Expertes (Démarrage)",
              icon: Icons.lightbulb,
              color: Colors.orange,
              content: """
Au début, quand vous n'avez pas assez de données, l'application utilise des règles médicales reconnues :

• Soda / Boissons gazeuses → Risque élevé de ballonnements (+40%).
• Alcool / Épices → Risque modéré d'inflammation.
• Repas tardifs (>21h) → Impact sur la digestion nocturne.
              """,
            ),
            const SizedBox(height: 16),
             _buildCard(
              title: "3. Apprentissage Continu",
              icon: Icons.psychology,
              color: Colors.purple,
              content: """
Plus vous utilisez l'application, plus les prédictions s'affinent. L'algorithme recalculera périodiquement les corrélations pour identifier des liens subtils, comme des aliments qui ne posent problème que le soir ou en période de stress.
              """,
            ),
            
             const SizedBox(height: 24),
            _buildSectionTitle('🔍 Transparence'),
            _buildSectionText(
              "Vos données ne quittent jamais votre appareil (sauf si vous activez la sauvegarde cloud). L'analyse est effectuée localement pour garantir votre confidentialité totale.",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.manrope(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF1E293B),
      ),
    );
  }

  Widget _buildSectionText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 15,
          color: const Color(0xFF475569),
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Color color,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
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
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF64748B),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
