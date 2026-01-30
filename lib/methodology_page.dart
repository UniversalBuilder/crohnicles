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
            _buildSectionTitle('📊 Analyse Statistique'),
            _buildSectionText(
              "Crohnicles analyse vos données personnelles pour identifier des corrélations entre vos repas et vos symptômes. Tout est calculé localement sur votre appareil.",
            ),
            const SizedBox(height: 24),
            
            _buildCard(
              title: "1. Corrélations Statistiques",
              icon: Icons.bar_chart,
              color: Colors.blue,
              content: """
L'application analyse votre historique personnel :

• Pour chaque ingrédient ou catégorie (ex: "Gluten", "Lactose").
• Elle calcule la probabilité P(Symptôme | Aliment) sur une fenêtre de 4-8h.
• Elle évalue la confiance basée sur le nombre d'observations (min. 10 échantillons pour haute confiance).

Exemple : Si vous avez mangé 10 fois du gluten et eu 6 fois des douleurs dans les 8h, le risque sera de 60% avec confiance de 100%.
              """,
            ),
             const SizedBox(height: 16),

            _buildCard(
              title: "2. Mode Temps Réel (Démarrage)",
              icon: Icons.speed,
              color: Colors.orange,
              content: """
Quand vous n'avez pas encore assez de données (< 30 repas), l'application utilise une analyse temps réel conservative :

• Analyse des 10 repas les plus similaires dans votre historique.
• Calcul de risque basé sur la fréquence des symptômes après ces repas.
• Confiance limitée à 30% maximum (s'améliore avec l'entraînement).

Dès que possible, entraînez le modèle statistique pour des prédictions personnalisées!
              """,
            ),
            const SizedBox(height: 16),
             _buildCard(
              title: "3. Entraînement du Modèle",
              icon: Icons.psychology,
              color: Colors.purple,
              content: """
Vous pouvez entraîner le modèle statistique manuellement (bouton 🧠 dans le tableau de bord) :

• Nécessite au moins 30 repas et 20 symptômes.
• Calcule toutes les corrélations significatives (probabilité > 10%, confiance > 30%).
• Les prédictions passent en mode "Modèle Personnel" avec confiance élevée.

Re-entraînez régulièrement (1x/mois) pour intégrer vos nouvelles données!
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
