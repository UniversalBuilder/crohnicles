import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'event_model.dart';
import 'database_helper.dart';
import 'app_theme.dart';
import 'package:intl/intl.dart';

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
      lastPain = allEventsModels.firstWhere((e) => e.type == EventType.symptom && e.severity >= 5);
    } catch (e) {
      lastPain = null;
    }

    List<EventModel> lastMeals = [];
    if (lastPain != null) {
       final rawMeals = await dbHelper.getLastMeals(3, beforeDate: lastPain.dateTime);
       lastMeals = rawMeals.map((e) => EventModel.fromMap(e)).toList();
    }

    // 3. Global Pattern Analysis (Top Suspects)
    final suspects = _analyzePatterns(allEventsModels);

    if (mounted) {
      setState(() {
        _painData = pain;
        _stoolData = stool;
        _zoneData = zones; // Set State
        _suspectMeals = lastMeals;
        _topSuspects = suspects;
        _isLoading = false;
      });
    }
  }

  Map<String, int> _analyzePatterns(List<EventModel> events) {
    Map<String, int> suspectCounts = {};
    
    final severeAttacks = events.where((e) => 
      e.type == EventType.symptom && 
      e.severity > 5
    ).toList();

    for (var attack in severeAttacks) {
        final attackTime = DateTime.parse(attack.dateTime);
        final startTime = attackTime.subtract(const Duration(hours: 24));
        
        final mealsBefore = events.where((e) {
             if (e.type != EventType.meal) return false;
             try {
               final eTime = DateTime.parse(e.dateTime);
               return eTime.isAfter(startTime) && eTime.isBefore(attackTime);
             } catch(e) { return false; }
        });

        for (var meal in mealsBefore) {
            // If we have tags (ingredients), count them
            // Otherwise use title
            if (meal.tags.isNotEmpty) {
              for(var tag in meal.tags) {
                if(tag.isEmpty || tag == "Repas" || tag == "Encas" || tag == "Grignotage") continue;
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
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
                _buildSuspectsCard(),
                const SizedBox(height: 24),
                
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
                   ..._suspectMeals.map((e) => Container(
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
                       leading: Container(
                         padding: const EdgeInsets.all(8),
                         decoration: BoxDecoration(
                           gradient: AppColors.mealGradient.scale(0.4),
                           borderRadius: BorderRadius.circular(12),
                         ),
                         child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                       ),
                       title: Text(
                         e.title,
                         style: GoogleFonts.inter(
                           fontWeight: FontWeight.w600,
                           color: AppColors.textPrimary,
                         ),
                       ),
                       subtitle: Text(
                         (e.dateTime.length > 10 ? DateFormat('dd/MM HH:mm').format(DateTime.parse(e.dateTime)) : e.dateTime) + "\n" + e.tags.join(', '),
                         style: GoogleFonts.inter(
                           fontSize: 12,
                           color: AppColors.textSecondary,
                         ),
                       ),
                       isThreeLine: true,
                     ),
                   )).toList(),
                ] else ...[
                   Text(
                     "Pas de données récentes de crise pour analyser les derniers repas.",
                     style: GoogleFonts.inter(
                       color: AppColors.textSecondary,
                     ),
                   ),
                ],
                
                const SizedBox(height: 40),
            ],
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
          border: Border.all(
            color: Colors.grey.shade300,
            width: 1.5,
          ),
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
              Text(
                "Déclencheurs Potentiels",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: AppColors.textPrimary,
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
       final date = DateTime(int.parse(dateParts[0]), int.parse(dateParts[1]), int.parse(dateParts[2]));
       final diff = date.difference(today).inDays; // e.g. -29 to 0
       
       // Map to 0..29 range where 29 is today
       final xVal = (30 + diff).toDouble(); 
       if (xVal >= 0 && xVal <= 30) {
         spots.add(FlSpot(xVal, (entry['max_severity'] as int).toDouble()));
       }
    }
    
    // Sort spots by x
    spots.sort((a,b) => a.x.compareTo(b.x));

    return LineChart(
      LineChartData(
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
                    return Padding(padding: const EdgeInsets.only(top: 8), child: Text(DateFormat('dd/MM').format(date), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)));
                 }
                 return const SizedBox();
              },
              interval: 1,
            ),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)))),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0, maxX: 30,
        minY: 0, maxY: 10,
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
              }
            ),
            belowBarData: BarAreaData(
              show: true,
              // Gradient Coral to transparent
              gradient: LinearGradient(
                colors: [AppColors.pain.withValues(alpha: 0.2), AppColors.pain.withValues(alpha: 0.0)],
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
            titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
            badgeWidget: isLarge ? null : null, 
          )
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
                     width: 10, height: 10, 
                     decoration: BoxDecoration(
                       color: colors[index % colors.length],
                       shape: BoxShape.circle,
                     ),
                   ),
                   const SizedBox(width: 8),
                   Text(name, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                 ],
               ),
             );
          }).toList(),
        )
      ],
    );
  }

  Widget _buildStoolChart() {
     final now = DateTime.now();
     final today = DateTime(now.year, now.month, now.day);
     
     List<BarChartGroupData> barGroups = [];
     
     for (var entry in _stoolData) {
       final dateParts = (entry['date'] as String).split('-');
       final date = DateTime(int.parse(dateParts[0]), int.parse(dateParts[1]), int.parse(dateParts[2]));
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
                 borderRadius: const BorderRadius.vertical(top: Radius.circular(4)) // Rounded Top
               )
             ]
           )
         );
       }
     }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 8, // Max stools to show per day before capping viz
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), // Too crowded for 30 bars, maybe show none or range
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 20, getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)))),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
      )
    );
  }
}
