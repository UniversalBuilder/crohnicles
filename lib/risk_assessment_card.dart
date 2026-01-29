import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ml/model_manager.dart';
import 'app_theme.dart';
import 'database_helper.dart';
import 'event_model.dart';

/// Bottom sheet displaying ML-powered risk assessment after meal logging
class RiskAssessmentCard extends StatefulWidget {
  final List<RiskPrediction> predictions;
  final EventModel meal;
  final VoidCallback onClose;

  const RiskAssessmentCard({
    super.key,
    required this.predictions,
    required this.meal,
    required this.onClose,
  });

  @override
  State<RiskAssessmentCard> createState() => _RiskAssessmentCardState();
}

class _RiskAssessmentCardState extends State<RiskAssessmentCard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseHelper _db = DatabaseHelper();
  List<EventModel> _similarMeals = [];
  bool _loadingSimilarMeals = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.predictions.length,
      vsync: this,
    );
    _loadSimilarMeals();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSimilarMeals() async {
    try {
      // Get first prediction's similar meal IDs
      if (widget.predictions.isNotEmpty &&
          widget.predictions.first.similarMealIds.isNotEmpty) {
        final dbInstance = await _db.database;
        final meals = <EventModel>[];

        for (final id in widget.predictions.first.similarMealIds) {
          final result = await dbInstance.query(
            'events',
            where: 'id = ?',
            whereArgs: [id],
            limit: 1,
          );

          if (result.isNotEmpty) {
            meals.add(EventModel.fromMap(result.first));
          }
        }

        setState(() {
          _similarMeals = meals;
          _loadingSimilarMeals = false;
        });
      } else {
        setState(() {
          _loadingSimilarMeals = false;
        });
      }
    } catch (e) {
      print('[RiskAssessmentCard] Error loading similar meals: $e');
      setState(() {
        _loadingSimilarMeals = false;
      });
    }
  }

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel) {
      case 'low':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getRiskIcon(String riskLevel) {
    switch (riskLevel) {
      case 'low':
        return Icons.check_circle;
      case 'medium':
        return Icons.warning;
      case 'high':
        return Icons.error;
      default:
        return Icons.help;
    }
  }

  String _getSymptomName(String symptomType) {
    const names = {
      'pain': 'Douleurs',
      'diarrhea': 'Diarrhée',
      'bloating': 'Ballonnements',
    };
    return names[symptomType] ?? symptomType;
  }

  /// Build subtitle that distinguishes ML predictions from correlation fallback
  Widget _buildSubtitle() {
    // Check average confidence to determine if using ML models or fallback
    final avgConfidence = widget.predictions.isEmpty
        ? 0.0
        : widget.predictions.map((p) => p.confidence).reduce((a, b) => a + b) /
              widget.predictions.length;

    final isUsingML = avgConfidence > 0.65;

    return Text(
      isUsingML
          ? 'Prédictions par IA entraînée sur vos données'
          : 'Corrélations simples (modèles ML non entraînés)',
      style: GoogleFonts.inter(
        fontSize: 13,
        color: Colors.grey.shade600,
        fontStyle: isUsingML ? FontStyle.normal : FontStyle.italic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.mealGradient.colors.first.withValues(alpha: 0.1),
                  AppColors.mealGradient.colors.last.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: AppColors.mealGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.analytics_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Évaluation des Risques',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          _buildSubtitle(),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Symptom tabs
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: AppColors.mealGradient.colors.first,
                    unselectedLabelColor: Colors.grey.shade600,
                    indicator: BoxDecoration(
                      gradient: AppColors.mealGradient.scale(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    labelStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                    tabs: widget.predictions.map((pred) {
                      return Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              pred.riskEmoji,
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                _getSymptomName(pred.symptomType),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: widget.predictions.map((pred) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPredictionContent(pred),
                      const SizedBox(height: 24),
                      _buildMealFoodsList(),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // Footer actions
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Show detailed explanation
                      _showDetailedExplanation(context);
                    },
                    icon: const Icon(Icons.help_outline, size: 18),
                    label: const Text('Comprendre'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: AppColors.mealGradient.colors.first,
                      ),
                      foregroundColor: AppColors.mealGradient.colors.first,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Compris'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppColors.mealGradient.colors.first,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionContent(RiskPrediction prediction) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Risk level badge
          _buildRiskBadge(prediction),
          const SizedBox(height: 24),

          // Explanation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey.shade600, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    prediction.explanation,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade800,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Top factors
          if (prediction.topFactors.isNotEmpty) ...[
            Text(
              'Facteurs de risque identifiés',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...prediction.topFactors.map((factor) => _buildFactorItem(factor)),
            const SizedBox(height: 24),
          ],

          // Similar meals
          if (!_loadingSimilarMeals && _similarMeals.isNotEmpty) ...[
            Text(
              'Repas similaires',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _similarMeals.length,
                itemBuilder: (context, index) {
                  return _buildSimilarMealCard(_similarMeals[index]);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRiskBadge(RiskPrediction prediction) {
    final color = _getRiskColor(prediction.riskLevel);
    final icon = _getRiskIcon(prediction.riskLevel);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Risque ${prediction.riskLevel == "low"
                      ? "faible"
                      : prediction.riskLevel == "medium"
                      ? "modéré"
                      : "élevé"}',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(prediction.riskScore * 100).toStringAsFixed(0)}% de probabilité',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Confiance: ${(prediction.confidence * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactorItem(TopFactor factor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.mealGradient.colors.first,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              factor.humanReadable,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.mealGradient.colors.first.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '+${(factor.contribution * 100).toStringAsFixed(0)}%',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.mealGradient.colors.first,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimilarMealCard(EventModel meal) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.restaurant,
                size: 16,
                color: AppColors.mealGradient.colors.first,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  DateTime.parse(meal.dateTime).day == DateTime.now().day
                      ? "Aujourd'hui"
                      : 'Il y a ${DateTime.now().difference(DateTime.parse(meal.dateTime)).inDays}j',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            meal.tags.take(2).join(', '),
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showDetailedExplanation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Comment fonctionne l\'évaluation ?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Crohnicles utilise l\'intelligence artificielle pour analyser vos repas et prédire les risques de symptômes.',
                style: GoogleFonts.inter(height: 1.5),
              ),
              const SizedBox(height: 16),
              _buildExplanationPoint(
                'Analyse des données',
                'Le modèle analyse 60+ facteurs : ingrédients, moment du repas, météo, historique...',
              ),
              _buildExplanationPoint(
                'Apprentissage continu',
                'Plus vous utilisez l\'app, plus les prédictions deviennent personnalisées.',
              ),
              _buildExplanationPoint(
                'Confidentialité',
                'Toutes les analyses sont faites localement sur votre appareil.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  Widget _buildMealFoodsList() {
    try {
      if (widget.meal.metaData == null || widget.meal.metaData!.isEmpty) {
        return const SizedBox.shrink();
      }

      final data = jsonDecode(widget.meal.metaData!);
      final foods = data['foods'] as List?;

      if (foods == null || foods.isEmpty) {
        return const SizedBox.shrink();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aliments dans ce repas',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...foods.map((food) {
            final name = food['name'] ?? 'Inconnu';
            final tags = (food['tags'] as List?)?.cast<String>() ?? [];

            // Determine if risky based on tags
            final riskyTags = [
              'gras',
              'gluten',
              'lactose',
              'épicé',
              'alcool',
              'fermenté',
            ];
            final foodRiskyTags = tags
                .where((tag) => riskyTags.contains(tag.toLowerCase()))
                .toList();
            final isRisky = foodRiskyTags.isNotEmpty;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isRisky ? Colors.red.shade50 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isRisky ? Colors.red.shade200 : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isRisky ? Icons.warning_amber : Icons.check_circle_outline,
                    color: isRisky
                        ? Colors.red.shade700
                        : Colors.green.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (tags.isNotEmpty)
                          Text(
                            tags.join(', '),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        if (isRisky && foodRiskyTags.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '⚠️ Potentiellement risqué: ${foodRiskyTags.join(', ')}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      );
    } catch (e) {
      print('[RiskAssessmentCard] Error parsing meal foods: $e');
      return const SizedBox.shrink();
    }
  }

  Widget _buildExplanationPoint(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            size: 20,
            color: AppColors.mealGradient.colors.first,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
