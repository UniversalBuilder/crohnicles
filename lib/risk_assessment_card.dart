import 'dart:convert';
import 'package:flutter/material.dart';
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
      'joints': 'Articulations',
      'skin': 'Peau',
      'oral': 'Bouche/ORL',
      'systemic': 'Général',
    };
    return names[symptomType] ?? symptomType;
  }

  /// Build subtitle that distinguishes trained model from real-time analysis
  Widget _buildSubtitle() {
    // Use ModelManager to check if trained model is being used
    final modelManager = ModelManager();
    final isUsingTrainedModel = modelManager.isUsingTrainedModel;

    return Text(
      isUsingTrainedModel
          ? 'Basé sur votre modèle statistique personnel'
          : 'Analyse en temps réel (entraînez le modèle pour personnaliser)',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontStyle: isUsingTrainedModel ? FontStyle.normal : FontStyle.italic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
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
                            style: Theme.of(context).textTheme.headlineSmall,
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
                // Symptom tabs (horizontal scrollable)
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    itemCount: widget.predictions.length,
                    itemBuilder: (context, index) {
                      final pred = widget.predictions[index];
                      final isSelected = _tabController.index == index;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _tabController.animateTo(index);
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? AppColors.mealGradient.scale(0.15)
                                : null,
                            color: isSelected
                                ? null
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                pred.riskEmoji,
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _getSymptomName(pred.symptomType),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? AppColors.mealGradient.colors.first
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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
              color: Theme.of(context).colorScheme.surface,
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
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    prediction.explanation,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(height: 1.5),
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
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...prediction.topFactors.map((factor) => _buildFactorItem(factor)),
            const SizedBox(height: 24),
          ],

          // Similar meals
          if (!_loadingSimilarMeals && _similarMeals.isNotEmpty) ...[
            Text(
              'Repas similaires',
              style: Theme.of(context).textTheme.titleMedium,
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
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(prediction.riskScore * 100).toStringAsFixed(0)}% de probabilité',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Confiance: ${(prediction.confidence * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
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
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            meal.tags.take(2).join(', '),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
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
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Crohnicles utilise l\'intelligence artificielle pour analyser vos repas et prédire les risques de symptômes.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.5),
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

      final decoded = jsonDecode(widget.meal.metaData!);
      List<dynamic>? foods;

      if (decoded is List) {
        foods = decoded;
      } else if (decoded is Map && decoded.containsKey('foods')) {
        var foodsRaw = decoded['foods'];

        // Handle double-encoded JSON case
        if (foodsRaw is String) {
          try {
            foodsRaw = jsonDecode(foodsRaw);
          } catch (e) {
            print('[RiskAssessmentCard] Failed to decode inner foods JSON: $e');
          }
        }

        if (foodsRaw is List) {
          foods = foodsRaw;
        }
      }

      if (foods == null || foods.isEmpty) {
        return const SizedBox.shrink();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aliments dans ce repas',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ...foods.map((food) {
            String name = 'Inconnu';
            if (food is Map && food.containsKey('name')) {
              name = food['name'];
            }

            List<String> tags = [];
            if (food is Map && food.containsKey('tags')) {
              if (food['tags'] is List) {
                tags = (food['tags'] as List).map((e) => e.toString()).toList();
              } else if (food['tags'] is String) {
                tags = (food['tags'] as String)
                    .split(',')
                    .where((e) => e.isNotEmpty)
                    .toList();
              }
            }

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
                color: isRisky
                    ? Theme.of(context).colorScheme.error.withValues(alpha: 0.1)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isRisky
                      ? Theme.of(
                          context,
                        ).colorScheme.error.withValues(alpha: 0.3)
                      : Theme.of(context).colorScheme.outline,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isRisky ? Icons.warning_amber : Icons.check_circle_outline,
                    color: isRisky
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.tertiary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (tags.isNotEmpty)
                          Text(
                            tags.join(', '),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        if (isRisky && foodRiskyTags.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '⚠️ Potentiellement risqué: ${foodRiskyTags.join(', ')}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
