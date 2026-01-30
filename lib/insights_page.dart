import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'event_model.dart';
import 'database_helper.dart';
import 'app_theme.dart';
import 'package:intl/intl.dart';
import 'ml/model_manager.dart';
import 'event_detail_page.dart';
import 'services/training_service.dart';
import 'ml/model_status_page.dart';
import 'methodology_page.dart';

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  bool _isLoading = true;

  // Real Data
  List<Map<String, dynamic>> _painData = [];
  List<Map<String, dynamic>> _stoolData = [];
  Map<String, int> _zoneData = {}; // New State
  List<EventModel> _suspectMeals = [];

  // Analysis
  Map<String, int> _topSuspects = {};

  // ML Data
  Map<String, List<Map<String, dynamic>>> _correlations = {};
  ModelManager? _modelManager;
  bool _hasModels = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final dbHelper = DatabaseHelper();

    // 1. Chart Data
    final pain = await dbHelper.getPainEvolution(30);
    final stool = await dbHelper.getStoolFrequency(30);
    final zones = await dbHelper.getSymptomZones(30); // New Query

    // 2. Suspect Meals Logic
    // Find the latest high pain event
    final events = await dbHelper.getEvents(); // Get all for analysis logic
    final allEventsModels = events.map((e) => EventModel.fromMap(e)).toList();

    EventModel? lastPain;
    try {
      lastPain = allEventsModels.firstWhere(
        (e) => e.type == EventType.symptom && e.severity >= 5,
      );
    } catch (e) {
      lastPain = null;
    }

    List<EventModel> lastMeals = [];
    if (lastPain != null) {
      final rawMeals = await dbHelper.getLastMeals(
        3,
        beforeDate: lastPain.dateTime,
      );
      lastMeals = rawMeals.map((e) => EventModel.fromMap(e)).toList();
    }

    // 3. Global Pattern Analysis (Top Suspects)
    final suspects = _analyzePatterns(allEventsModels);

    // 4. ML Correlations
    final Map<String, List<Map<String, dynamic>>> correlations = {};

    // Get correlations for common tags - simplified calculation
    final tagsToCheck = [
      'Gras',
      'Gluten',
      'Lactose',
      'Épicé',
      'Alcool',
      'Gaz',
    ];
    
    final severeSymptoms = allEventsModels
        .where((e) => e.type == EventType.symptom && e.severity >= 6)
        .toList();
    
    for (final tag in tagsToCheck) {
      int tagCount = 0;
      int symptomAfterTag = 0;

      final mealsWithTag = allEventsModels
          .where((e) => e.type == EventType.meal && e.tags.contains(tag))
          .toList();

      tagCount = mealsWithTag.length;

      for (final meal in mealsWithTag) {
        try {
          final mealTime = DateTime.parse(meal.dateTime);
          final hasSymptomAfter = severeSymptoms.any((symptom) {
            final symptomTime = DateTime.parse(symptom.dateTime);
            final diff = symptomTime.difference(mealTime);
            // IBD symptoms can appear 2-24 hours after a trigger meal
            return diff.inHours >= 2 && diff.inHours <= 24;
          });

          if (hasSymptomAfter) symptomAfterTag++;
        } catch (e) {
          // Skip invalid dates
        }
      }

      if (tagCount > 0) {
        final correlation = symptomAfterTag / tagCount;
        correlations[tag] = [
          {
            'correlation': correlation,
            'count': tagCount,
            'symptoms': symptomAfterTag,
          }
        ];
      }
    }

    // 5. Try to load ML models
    ModelManager? modelManager;
    bool hasModels = false;
    try {
      modelManager = ModelManager();
      await modelManager.initialize();
      // Check if models are actually loaded (not just fallback)
      hasModels = modelManager.isReady;
    } catch (e) {
      print('[INSIGHTS] Model loading failed (using fallback): $e');
    }

    if (mounted) {
      setState(() {
        _painData = pain;
        _stoolData = stool;
        _zoneData = zones; // Set State
        _suspectMeals = lastMeals;
        _topSuspects = suspects;
        _correlations = correlations;
        _modelManager = modelManager;
        _hasModels = hasModels;
        _isLoading = false;
      });
    }
  }

  Map<String, int> _analyzePatterns(List<EventModel> events) {
    Map<String, int> suspectCounts = {};

    final severeAttacks = events
        .where((e) => e.type == EventType.symptom && e.severity > 5)
        .toList();

    for (var attack in severeAttacks) {
      final attackTime = DateTime.parse(attack.dateTime);
      final startTime = attackTime.subtract(const Duration(hours: 24));

      final mealsBefore = events.where((e) {
        if (e.type != EventType.meal) return false;
        try {
          final eTime = DateTime.parse(e.dateTime);
          return eTime.isAfter(startTime) && eTime.isBefore(attackTime);
        } catch (e) {
          return false;
        }
      });

      for (var meal in mealsBefore) {
        // If we have tags (ingredients), count them
        // Otherwise use title
        if (meal.tags.isNotEmpty) {
          for (var tag in meal.tags) {
            if (tag.isEmpty ||
                tag == "Repas" ||
                tag == "Encas" ||
                tag == "Grignotage") {
              continue;
            }
            suspectCounts[tag] = (suspectCounts[tag] ?? 0) + 1;
          }
        } else {
          final foodName = meal.title.trim();
          suspectCounts[foodName] = (suspectCounts[foodName] ?? 0) + 1;
        }
      }
    }

    // Sort by count desc
    var sortedKeys = suspectCounts.keys.toList(growable: false)
      ..sort((k1, k2) => suspectCounts[k2]!.compareTo(suspectCounts[k1]!));

    final Map<String, int> top = {};
    for (var k in sortedKeys.take(5)) {
      top[k] = suspectCounts[k]!;
    }
    return top;
  }

  /// Trigger ML model training
  Future<void> _triggerTraining() async {
    final trainingService = TrainingService();
    
    // Show loading dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Analyse statistique en cours...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Check data availability first
      final dataStatus = await trainingService.checkDataAvailability();
      
      if (!dataStatus.hasEnoughData) {
        if (!mounted) return;
        Navigator.pop(context); // Close loading dialog
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Données insuffisantes'),
            content: Text(dataStatus.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // Trigger training
      TrainingResult result;
      
      // Call service (logic handles platform switch internally now)
      result = await trainingService.trainModels();
      
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Show result
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(result.success ? 'Analyse terminée' : 'Erreur'),
          content: Text(result.message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (result.success) {
                  // Reload data to show new predictions
                  setState(() => _isLoading = true);
                  _loadData();
                }
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Erreur'),
          content: Text('Échec de l\'entraînement: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
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
          "Tableau de Bord",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            tooltip: 'Statut des Modèles ML',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ModelStatusPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.model_training),
            tooltip: Platform.isAndroid || Platform.isIOS
                ? 'Entraînement (Desktop uniquement)'
                : 'Entraîner les modèles ML',
            onPressed: _triggerTraining,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir les statistiques',
            onPressed: () {
              setState(() => _isLoading = true);
              _loadData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSuspectsCard(),
                const SizedBox(height: 24),

                // Show latest meal risk if available (New)
                if (_suspectMeals.isNotEmpty) ...[
                   _buildLastRiskAssessmentCard(),
                   const SizedBox(height: 24),
                ],

                // ML Predictions Section
                if (_modelManager != null) ...[
                  _buildMLPredictionsCard(),
                  const SizedBox(height: 24),
                ],

                // Correlations Section
                if (_correlations.isNotEmpty) ...[
                  _buildCorrelationsCard(),
                  const SizedBox(height: 24),
                ],

                // --- PAIN CHART ---
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Courbe de Douleur (30j)",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 3,
                      width: 60,
                      decoration: BoxDecoration(
                        gradient: AppColors.painGradient,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.95),
                        AppColors.surfaceGlass.withValues(alpha: 0.5),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.painStart.withValues(alpha: 0.15),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.painStart.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                    child: SizedBox(height: 250, child: _buildPainChart()),
                  ),
                ),

                const SizedBox(height: 24),

                // --- ZONES CHART ---
                if (_zoneData.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Localisation des Douleurs",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 3,
                        width: 60,
                        decoration: BoxDecoration(
                          gradient: AppColors.painGradient,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.95),
                          AppColors.surfaceGlass.withValues(alpha: 0.5),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.painStart.withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(height: 220, child: _buildZoneChart()),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // --- STOOL CHART ---
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Fréquence du Transit (30j)",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 3,
                      width: 60,
                      decoration: BoxDecoration(
                        gradient: AppColors.stoolGradient,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.95),
                        AppColors.surfaceGlass.withValues(alpha: 0.5),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.stoolStart.withValues(alpha: 0.15),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.stoolStart.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(height: 200, child: _buildStoolChart()),
                  ),
                ),

                const SizedBox(height: 24),

                // --- RECENT SUSPECT MEALS ---
                if (_suspectMeals.isNotEmpty) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Derniers repas avant crise",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.painEnd,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 3,
                        width: 60,
                        decoration: BoxDecoration(
                          gradient: AppColors.mealGradient,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Aliments pris avant la dernière douleur > 5/10",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._suspectMeals
                      .map(
                        (e) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                AppColors.mealStart.withValues(alpha: 0.08),
                                Colors.white.withValues(alpha: 0.95),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.mealStart.withValues(alpha: 0.2),
                              width: 1.5,
                            ),
                          ),
                          child: ListTile(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EventDetailPage(event: e),
                                ),
                              );
                            },
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: AppColors.mealGradient.scale(0.4),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              e.title,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              "${e.dateTime.length > 10
                                      ? DateFormat(
                                          'dd/MM HH:mm',
                                        ).format(DateTime.parse(e.dateTime))
                                      : e.dateTime}\n${e.tags.join(', ')}",
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            isThreeLine: true,
                          ),
                        ),
                      )
                      ,
                ] else ...[
                  Text(
                    "Pas de données récentes de crise pour analyser les derniers repas.",
                    style: GoogleFonts.inter(color: AppColors.textSecondary),
                  ),
                ],

                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildLastRiskAssessmentCard() {
    return Card(
      elevation: 0,
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.blue.shade100),
      ),
      child: InkWell(
        onTap: () {
          // Trigger risk assessment for the last meal
          if (_suspectMeals.isNotEmpty) {
             // We need context, but we don't have it stored historically perfectly.
             // We can pass a dummy context or try to reconstruct.
             // For now, we will show a dialog saying "Context historique non disponible"
             // Or better, just show the detail page.
             Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EventDetailPage(event: _suspectMeals.first),
                ),
              );
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.assessment, color: Colors.blue),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Dernière analyse",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    Text(
                      "Cliquez pour voir les détails du dernier repas",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blue),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuspectsCard() {
    if (_topSuspects.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.95),
              AppColors.surfaceGlass.withValues(alpha: 0.5),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
        ),
        padding: const EdgeInsets.all(16),
        child: Text(
          "Pas encore assez de données pour détecter des déclencheurs.",
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryStart.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryStart.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryStart.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient.scale(0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.analytics_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Déclencheurs Potentiels",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      "Tags les plus fréquents dans vos repas",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _topSuspects.entries.map((e) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryStart.withValues(alpha: 0.15),
                      AppColors.primaryEnd.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primaryStart.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  "${e.key} (${e.value})",
                  style: GoogleFonts.inter(
                    color: AppColors.primaryEnd,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPainChart() {
    // Transform SQL data (Date Text, Int Max) to FlSpots
    // X axis: Day index (0 to 30)
    // We map date string to relative day index
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    List<FlSpot> spots = [];

    for (var entry in _painData) {
      // date format from sqlite is YYYY-MM-DD
      final dateParts = (entry['date'] as String).split('-');
      final date = DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
      );
      final diff = date.difference(today).inDays; // e.g. -29 to 0

      // Map to 0..29 range where 29 is today
      final xVal = (30 + diff).toDouble();
      if (xVal >= 0 && xVal <= 30) {
        spots.add(FlSpot(xVal, (entry['max_severity'] as int).toDouble()));
      }
    }

    // Sort spots by x
    spots.sort((a, b) => a.x.compareTo(b.x));

    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(
          enabled: true,
          touchCallback: (event, response) {
            if (event is FlTapUpEvent && response?.lineBarSpots != null) {
              final spot = response!.lineBarSpots!.first;
              final dayIndex = spot.x.toInt();
              final date = today.add(Duration(days: dayIndex - 30));
              _showEventsForDay(date);
            }
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final dayIndex = spot.x.toInt();
                final date = today.add(Duration(days: dayIndex - 30));
                return LineTooltipItem(
                  '${DateFormat('dd/MM').format(date)}\n${spot.y.toInt()}/10',
                  GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                // Show date every 5 days
                final dayIndex = value.toInt();
                final date = today.add(Duration(days: dayIndex - 30));
                if (dayIndex % 5 == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('dd/MM').format(date),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
              interval: 1,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 30,
        minY: 0,
        maxY: 10,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.pain,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, barData) {
                return spot.x == 30; // Only show last point
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              // Gradient Coral to transparent
              gradient: LinearGradient(
                colors: [
                  AppColors.pain.withValues(alpha: 0.2),
                  AppColors.pain.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneChart() {
    // Palette sobre et professionnelle pour la visualisation médicale
    final List<Color> colors = [
      AppColors.stool, // Indigo
      AppColors.primary.withValues(alpha: 0.8), // Forest Green
      AppColors.checkup, // Blue Grey
      const Color(0xFF8D6E63), // Brown muted
      const Color(0xFF26A69A), // Teal muted
      const Color(0xFFAB47BC), // Purple muted
      const Color(0xFFFFA726), // Orange muted
    ];

    int i = 0;
    List<PieChartSectionData> sections = [];

    _zoneData.forEach((key, value) {
      final isLarge = value > 5;
      final color = colors[i % colors.length];

      sections.add(
        PieChartSectionData(
          color: color,
          value: value.toDouble(),
          title: isLarge ? "$key\n$value" : value.toString(),
          radius: isLarge ? 55 : 45, // Slightly reduced size
          titleStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          badgeWidget: isLarge ? null : null,
        ),
      );
      i++;
    });

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 40,
              sectionsSpace: 2,
              startDegreeOffset: 180,
            ),
          ),
        ),
        // Legend
        const SizedBox(width: 24),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _zoneData.keys.toList().asMap().entries.map((e) {
            final index = e.key;
            final name = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colors[index % colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStoolChart() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    List<BarChartGroupData> barGroups = [];

    for (var entry in _stoolData) {
      final dateParts = (entry['date'] as String).split('-');
      final date = DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
      );
      final diff = date.difference(today).inDays; // e.g. -29 to 0
      final xVal = (30 + diff);

      if (xVal >= 0 && xVal <= 30) {
        final count = (entry['count'] as int).toDouble();
        barGroups.add(
          BarChartGroupData(
            x: xVal,
            barRods: [
              BarChartRodData(
                toY: count,
                color: AppColors.stool,
                width: 8,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ), // Rounded Top
              ),
            ],
          ),
        );
      }
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 8, // Max stools to show per day before capping viz
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ), // Too crowded for 30 bars, maybe show none or range
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
      ),
    );
  }

  Widget _buildMLPredictionsCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.95),
            AppColors.surfaceGlass.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryStart.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryStart.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.psychology,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Prédictions ML",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      _hasModels ? "Modèles entraînés" : "Mode fallback",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _hasModels ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.help_outline, color: AppColors.textSecondary),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MethodologyPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceGlass.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryStart.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _hasModels
                        ? "Les modèles sont entraînés sur vos données personnelles pour prédire les réactions à vos repas."
                        : "Les prédictions utilisent des corrélations statistiques. Entraînez les modèles après 30+ repas pour des prédictions personnalisées.",
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppColors.primaryStart.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Les prédictions s'affichent automatiquement après chaque repas.",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCorrelationsCard() {
    // Sort correlations by strength
    final sortedTags = _correlations.entries.toList()
      ..sort((a, b) {
        final aStrength = a.value.isNotEmpty
            ? (a.value[0]['correlation'] as double).abs()
            : 0.0;
        final bStrength = b.value.isNotEmpty
            ? (b.value[0]['correlation'] as double).abs()
            : 0.0;
        return bStrength.compareTo(aStrength);
      });

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.95),
            AppColors.surfaceGlass.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange, Colors.deepOrange],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.warning_amber,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Déclencheurs Identifiés",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        "% de repas avec ce tag suivis de symptômes (2-24h)",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...sortedTags.take(5).map((entry) {
              final tag = entry.key;
              final correlationData = entry.value.isNotEmpty
                  ? entry.value[0]
                  : null;

              if (correlationData == null) return const SizedBox.shrink();

              final correlation = (correlationData['correlation'] as double)
                  .abs();
              final significance = correlation > 0.5
                  ? 'Forte'
                  : (correlation > 0.3 ? 'Modérée' : 'Faible');
              final color = correlation > 0.5
                  ? Colors.red
                  : (correlation > 0.3
                        ? Colors.orange
                        : Colors.yellow.shade700);

              return GestureDetector(
                onTap: () => _showMealsWithTag(tag),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color.withValues(alpha: 0.8), color],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tag,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "Corrélation $significance",
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                "${(correlationData['symptoms'] as int)}/${(correlationData['count'] as int)}",
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          LinearProgressIndicator(
                            value: correlation,
                            backgroundColor: color.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "${(correlation * 100).toStringAsFixed(0)}%",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showEventsForDay(DateTime date) async {
    final db = DatabaseHelper();
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    final allEvents = await db.getEvents();
    final eventsForDay = allEvents
        .map((e) => EventModel.fromMap(e))
        .where((e) {
          try {
            final eventDate = DateTime.parse(e.dateTime);
            return eventDate.isAfter(startOfDay) && eventDate.isBefore(endOfDay);
          } catch (e) {
            return false;
          }
        })
        .toList();
    
    if (eventsForDay.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aucun événement le ${DateFormat('dd/MM/yyyy').format(date)}')),
      );
      return;
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Événements du ${DateFormat('dd/MM/yyyy', 'fr_FR').format(date)}',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: eventsForDay.length,
                itemBuilder: (context, index) {
                  final event = eventsForDay[index];
                  final eventTime = DateTime.parse(event.dateTime);
                  
                  IconData icon;
                  Color color;
                  
                  switch (event.type) {
                    case EventType.meal:
                      icon = event.isSnack ? Icons.local_cafe : Icons.restaurant;
                      color = AppColors.mealStart;
                      break;
                    case EventType.symptom:
                      icon = Icons.favorite_border;
                      color = AppColors.painStart;
                      break;
                    case EventType.stool:
                      icon = Icons.analytics_outlined;
                      color = AppColors.stoolStart;
                      break;
                    default:
                      icon = Icons.event_note;
                      color = AppColors.primaryStart;
                  }
                  
                  return ListTile(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EventDetailPage(event: event),
                        ),
                      );
                    },
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.15),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    title: Text(
                      event.title,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      DateFormat('HH:mm').format(eventTime),
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                    trailing: event.type == EventType.symptom && event.severity > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${event.severity}/10',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          )
                        : null,
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showMealsWithTag(String tag) async {
    final db = DatabaseHelper();
    final allEvents = await db.getEvents();
    final mealsWithTag = allEvents
        .map((e) => EventModel.fromMap(e))
        .where((e) => e.type == EventType.meal && e.tags.contains(tag))
        .toList();
    
    if (mealsWithTag.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aucun repas trouvé avec le tag "$tag"')),
      );
      return;
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: AppColors.mealGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tag,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${mealsWithTag.length} repas',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: mealsWithTag.length,
                  itemBuilder: (context, index) {
                    final meal = mealsWithTag[index];
                    final mealTime = DateTime.parse(meal.dateTime);
                    
                    return ListTile(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EventDetailPage(event: meal),
                          ),
                        );
                      },
                      leading: CircleAvatar(
                        backgroundColor: AppColors.mealStart.withValues(alpha: 0.15),
                        child: Icon(
                          meal.isSnack ? Icons.local_cafe : Icons.restaurant,
                          color: AppColors.mealStart,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        meal.title,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(mealTime),
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
