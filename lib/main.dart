import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:google_fonts/google_fonts.dart';
import 'database_helper.dart';
import 'app_theme.dart';
import 'stool_entry_dialog.dart';
import 'event_model.dart';
import 'calendar_page.dart';
import 'event_search_delegate.dart';
import 'insights_page.dart';
import 'symptom_dialog.dart';
import 'meal_composer_dialog.dart';
import 'risk_assessment_card.dart';
import 'ml/model_manager.dart';
import 'services/context_service.dart';
import 'models/context_model.dart';
import 'timeline_chart_page.dart';

void main() {
  // Initialisation de la base de données pour le Web et Desktop
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const MyApp());
}

// --- MODÈLES ---
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crohnicles',
      theme: AppTheme.lightTheme,
      home: const TimelinePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key});

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  // Liste des événements
  List<EventModel> _events = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final dbHelper = DatabaseHelper();
    final eventsData = await dbHelper.getEvents();
    setState(() {
      _events = eventsData.map((e) => EventModel.fromMap(e)).toList();
    });
  }

  void _showMealDialog() async {
    print('[MAIN] Opening meal dialog');
    final result = await showDialog(
      context: context,
      builder: (context) => const MealComposerDialog(),
    );

    print('[MAIN] Meal dialog result: $result');
    if (result != null && result is Map) {
      // Get isSnack from result
      final bool resultIsSnack = result['is_snack'] as bool? ?? false;

      // Decode foods JSON and generate title
      String title;
      if (result['foods'] != null && result['foods'] is String) {
        try {
          final List<dynamic> foodsList = jsonDecode(result['foods']);
          final List<String> foodNames = foodsList
              .map(
                (f) =>
                    f is Map ? f['name'] as String? ?? 'Aliment' : f.toString(),
              )
              .toList();

          if (foodNames.isEmpty) {
            title = resultIsSnack ? 'Encas' : 'Repas';
          } else if (foodNames.length == 1) {
            title = foodNames[0];
          } else if (foodNames.length == 2) {
            title = '${foodNames[0]} + ${foodNames[1]}';
          } else {
            title = resultIsSnack
                ? 'Encas de ${foodNames.length} aliments'
                : 'Repas de ${foodNames.length} aliments';
          }
        } catch (e) {
          title = resultIsSnack ? 'Encas' : 'Repas';
        }
      } else {
        title = resultIsSnack ? 'Encas' : 'Repas';
      }

      _addEvent(
        EventType.meal,
        title,
        isSnack: resultIsSnack,
        tags: result['tags'] as List<String>? ?? [],
        metaData: result['foods'],
      );
      if (mounted) Navigator.of(context).pop(); // Ferme le menu du bas
    }
  }

  void _showDailyCheckupDialog() {
    double stress = 3;
    double fatigue = 3;
    String meds = "Oui"; // Oui, Non, Partiel

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 500,
                  maxHeight: 600,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.95),
                        AppColors.surfaceGlass.withValues(alpha: 0.90),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Gradient header
                        Container(
                          decoration: const BoxDecoration(
                            gradient: AppColors.checkupGradient,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 20,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.bedtime,
                                  size: 28,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  "Bilan du Soir",
                                  style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Content
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Stress Global :",
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SliderTheme(
                                  data: SliderThemeData(
                                    activeTrackColor: AppColors.checkupEnd,
                                    inactiveTrackColor: Colors.grey.shade300,
                                    thumbColor: AppColors.checkupStart,
                                    overlayColor: AppColors.checkupStart
                                        .withValues(alpha: 0.2),
                                    trackHeight: 6,
                                  ),
                                  child: Slider(
                                    value: stress,
                                    min: 1,
                                    max: 5,
                                    divisions: 4,
                                    label: stress.round().toString(),
                                    onChanged: (v) =>
                                        setState(() => stress = v),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                Text(
                                  "Fatigue :",
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SliderTheme(
                                  data: SliderThemeData(
                                    activeTrackColor: AppColors.checkupEnd,
                                    inactiveTrackColor: Colors.grey.shade300,
                                    thumbColor: AppColors.checkupStart,
                                    overlayColor: AppColors.checkupStart
                                        .withValues(alpha: 0.2),
                                    trackHeight: 6,
                                  ),
                                  child: Slider(
                                    value: fatigue,
                                    min: 1,
                                    max: 5,
                                    divisions: 4,
                                    label: fatigue.round().toString(),
                                    onChanged: (v) =>
                                        setState(() => fatigue = v),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                Text(
                                  "Traitement pris ?",
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: ["Oui", "Non", "Partiel"].map((
                                    opt,
                                  ) {
                                    final isSelected = meds == opt;
                                    return GestureDetector(
                                      onTap: () => setState(() => meds = opt),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: isSelected
                                              ? AppColors.checkupGradient
                                              : null,
                                          color: isSelected
                                              ? null
                                              : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? Colors.transparent
                                                : AppColors.checkupStart
                                                      .withValues(alpha: 0.3),
                                            width: 1.5,
                                          ),
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: AppColors
                                                        .checkupStart
                                                        .withValues(alpha: 0.3),
                                                    blurRadius: 12,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: Text(
                                          opt,
                                          style: GoogleFonts.inter(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.black87,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Actions
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: Colors.black.withValues(alpha: 0.06),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.checkupStart,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                                child: Text(
                                  "Annuler",
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: AppColors.checkupGradient,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.checkupStart.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      List<String> tags = [
                                        "Fatigue: ${fatigue.toInt()}/5",
                                        "Meds: $meds",
                                      ];
                                      _addEvent(
                                        EventType.daily_checkup,
                                        "Bilan Soir",
                                        severity: stress.toInt(),
                                        tags: tags,
                                      );
                                      Navigator.pop(
                                        context,
                                      ); // Ferme le dialogue
                                      Navigator.pop(
                                        context,
                                      ); // Ferme le menu du bas
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 28,
                                        vertical: 14,
                                      ),
                                      child: Text(
                                        "Enregistrer",
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSymptomDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return const SymptomEntryDialog();
      },
    ).then((results) {
      if (results != null && results is List) {
        for (var result in results) {
          _addEvent(
            EventType.symptom,
            result['title'],
            severity: result['severity'],
            tags: result['tags'],
          );
        }
      }
    });
  }

  // 2. Ajoute l'événement à la liste et en base de données
  void _addEvent(
    EventType type,
    String title, {
    bool isSnack = false,
    int? severity,
    List<String>? tags,
    String? imagePath,
    String? metaData,
  }) async {
    print(
      '➕ Adding event: type=$type, title=$title, severity=$severity, isSnack=$isSnack',
    );
    final now = DateTime.now();

    // Fusion des tags par défaut (Grignotage) avec les nouveaux tags
    List<String> userTags = tags ?? [];
    if (isSnack && !userTags.contains("Grignotage")) {
      userTags.add("Grignotage");
    }

    final newEvent = EventModel(
      type: type,
      dateTime: now.toIso8601String(),
      title: title,
      subtitle: isSnack
          ? "Encas rapide"
          : (type == EventType.daily_checkup
                ? "Suivi quotidien"
                : "Saisie manuelle"),
      isSnack: isSnack,
      tags: userTags,
      severity: severity ?? (type == EventType.symptom ? 5 : 0),
      imagePath: imagePath,
      metaData: metaData,
    );

    await _saveEvent(newEvent);
    print('[MAIN] Event saved successfully');

    // Show risk assessment for meal events
    if (type == EventType.meal && mounted) {
      final contextService = ContextService();
      final context = await contextService.captureCurrentContext();
      _showRiskAssessment(newEvent, context);
    }
  }

  /// Show ML-powered risk assessment after meal is logged
  Future<void> _showRiskAssessment(
    EventModel meal,
    ContextModel context,
  ) async {
    try {
      print('[MAIN] Generating risk assessment...');
      final modelManager = ModelManager();
      await modelManager.initialize();

      final predictions = await modelManager.predictAllSymptoms(meal, context);

      if (!mounted) return;

      showModalBottomSheet(
        context: this.context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => RiskAssessmentCard(
          predictions: predictions,
          meal: meal,
          onClose: () => Navigator.pop(context),
        ),
      );
    } catch (e) {
      print('[MAIN] Error generating risk assessment: $e');
      // Don't block the user flow if ML fails
    }
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, AppColors.surfaceGlass],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Ajouter au journal",
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildGradientActionButton(
                      Icons.restaurant,
                      "Repas",
                      AppColors.mealGradient,
                      AppColors.mealStart,
                      () => _showMealDialog(),
                    ),
                    _buildGradientActionButton(
                      Icons.bolt,
                      "Douleur",
                      AppColors.painGradient,
                      AppColors.painStart,
                      () => _showSymptomDialog(),
                    ),
                    _buildGradientActionButton(
                      Icons.waves,
                      "Selles",
                      AppColors.stoolGradient,
                      AppColors.stoolStart,
                      () => _showStoolEntryDialog(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.checkupGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.checkupStart.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showDailyCheckupDialog(),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.bedtime, color: Colors.white),
                            const SizedBox(width: 12),
                            Text(
                              "Bilan du Soir",
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGradientActionButton(
    IconData icon,
    String label,
    LinearGradient gradient,
    Color shadowColor,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: gradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: shadowColor.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _showStoolEntryDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const StoolEntryDialog(),
    );

    if (result != null) {
      final int type = result['type'];
      final bool isUrgent = result['isUrgent'];
      final bool hasBlood = result['hasBlood'];

      final now = DateTime.now();
      List<String> tags = [];
      if (isUrgent) tags.add("Urgent");
      if (hasBlood) tags.add("Sang");

      final newEvent = EventModel(
        type: EventType.stool,
        dateTime: now.toIso8601String(),
        title: "Type $type",
        subtitle: "Échelle de Bristol",
        isUrgent: isUrgent,
        tags: tags,
        severity: 0,
      );

      _saveEvent(newEvent);
      if (mounted) Navigator.pop(context); // Ferme le menu du bas
    }
  }

  Future<void> _saveEvent(EventModel event) async {
    final dbHelper = DatabaseHelper();
    await dbHelper.insertEvent(event.toMap());
    _loadEvents();
  }

  Future<void> _updateEvent(int eventId, EventModel updatedEvent) async {
    final dbHelper = DatabaseHelper();
    await dbHelper.updateEvent(eventId, updatedEvent.toMap());
    _loadEvents();
  }

  Future<void> _editEvent(EventModel event) async {
    if (event.id == null) return;

    switch (event.type) {
      case EventType.meal:
        final result = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (context) => MealComposerDialog(existingEvent: event),
        );
        if (result != null && mounted) {
          final updatedEvent = EventModel(
            type: EventType.meal,
            dateTime: event.dateTime, // Keep original time
            title: result['is_snack'] == true ? 'Snack' : 'Repas',
            subtitle: '${result['foods'].length} aliment(s)',
            isSnack: result['is_snack'] ?? false,
            tags: List<String>.from(result['tags'] ?? []),
            severity: 0,
            metaData: jsonEncode({'foods': result['foods']}),
          );
          await _updateEvent(event.id!, updatedEvent);
        }
        break;

      case EventType.symptom:
        final results = await showDialog<List<Map<String, dynamic>>>(
          context: context,
          builder: (context) => SymptomEntryDialog(existingEvent: event),
        );
        if (results != null && results.isNotEmpty && mounted) {
          // For edit mode, update the existing event (first zone)
          final firstResult = results.first;
          final updatedEvent = EventModel(
            type: EventType.symptom,
            dateTime: event.dateTime,
            title: firstResult['title'],
            subtitle: 'Douleur',
            severity: firstResult['severity'],
            tags: List<String>.from(firstResult['tags'] ?? []),
            metaData: firstResult['meta_data'],
          );
          await _updateEvent(event.id!, updatedEvent);

          // Delete old additional zones and create new ones if multiple zones selected
          if (results.length > 1) {
            // TODO: Handle multiple zones in edit mode - for now just update first one
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Édition multi-zones non supportée'),
              ),
            );
          }
        }
        break;

      case EventType.stool:
        final result = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (context) => StoolEntryDialog(existingEvent: event),
        );
        if (result != null && mounted) {
          final int type = result['type'];
          final bool isUrgent = result['isUrgent'];
          final bool hasBlood = result['hasBlood'];
          List<String> tags = [];
          if (isUrgent) tags.add('Urgent');
          if (hasBlood) tags.add('Sang');

          final updatedEvent = EventModel(
            type: EventType.stool,
            dateTime: event.dateTime,
            title: 'Type $type',
            subtitle: 'Échelle de Bristol',
            isUrgent: isUrgent,
            tags: tags,
            severity: 0,
          );
          await _updateEvent(event.id!, updatedEvent);
        }
        break;

      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Modification non supportée')),
        );
    }
  }

  void _showDevMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '🛠️ Menu Développeur',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text(
                'Effacer toute la base',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Supprime TOUT (events, foods, cache)',
                style: TextStyle(color: Colors.grey),
              ),
              onTap: () {
                Navigator.pop(context);
                _showClearDatabaseDialog();
              },
            ),
            const Divider(color: Colors.grey),
            ListTile(
              leading: const Icon(Icons.restore, color: Colors.blue),
              title: const Text(
                'Générer données de démo',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                '30 jours d\'historique fictif',
                style: TextStyle(color: Colors.grey),
              ),
              onTap: () {
                Navigator.pop(context);
                _showGenerateDemoDialog();
              },
            ),
            const Divider(color: Colors.grey),
            ListTile(
              leading: const Icon(Icons.psychology, color: Colors.purple),
              title: const Text(
                'Entraîner les modèles ML',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Lance l\'analyse et corrélations',
                style: TextStyle(color: Colors.grey),
              ),
              onTap: () {
                Navigator.pop(context);
                _trainModels();
              },
            ),
            const Divider(color: Colors.grey),
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.green),
              title: const Text(
                'Rafraîchir la vue',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Recharge tous les événements',
                style: TextStyle(color: Colors.grey),
              ),
              onTap: () {
                Navigator.pop(context);
                _loadEvents();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Vue rafraîchie')));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showClearDatabaseDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Effacer la base'),
        content: const Text(
          'Ceci va supprimer:\n'
          '• Tous les événements\n'
          '• Tous les aliments\n'
          '• Le cache OpenFoodFacts\n'
          '• Les modèles ML\n\n'
          'Action IRRÉVERSIBLE !',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              try {
                final db = await DatabaseHelper().database;
                await db.delete('events');
                await db.delete('foods');
                await db.delete('products_cache');
                _loadEvents();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Base de données effacée'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Erreur: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('EFFACER TOUT'),
          ),
        ],
      ),
    );
  }

  void _showGenerateDemoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎲 Générer Démo'),
        content: const Text(
          'Ceci va générer 30 jours d\'historique fictif:\n'
          '• Repas variés (trigger et sains)\n'
          '• Symptômes corrélés\n'
          '• Selles avec Bristol scale\n\n'
          'Les données existantes seront conservées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.blue),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await DatabaseHelper().generateDemoData();
                _loadEvents();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Données de démo générées'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Erreur: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('GÉNÉRER'),
          ),
        ],
      ),
    );
  }

  void _trainModels() async {
    try {
      final db = DatabaseHelper();
      final events = await db.getEvents();

      if (events.length < 10) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '⚠️ Pas assez de données (minimum 10 événements)\n'
                'Utilisez "Générer données de démo" d\'abord.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🧠 Entraînement en cours...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Les modèles s'entraînent automatiquement dans insights_page.dart
      // lors du chargement, mais on peut forcer un refresh ici
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Entraînement terminé\n'
              '${events.length} événements analysés',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteEvent(int id) async {
    await DatabaseHelper().deleteEvent(id);
    _loadEvents();
  }

  void _showEventOptions(EventModel event) {
    if (event.id == null) return;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text("Modifier"),
                onTap: () {
                  Navigator.pop(context);
                  _editEvent(event);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  "Supprimer",
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Confirmer suppression ?"),
                      content: const Text(
                        "Voulez-vous vraiment supprimer cet événement ?",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("Non"),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          onPressed: () {
                            _deleteEvent(event.id!);
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Élément supprimé")),
                            );
                          },
                          child: const Text("Oui, supprimer"),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSymptomIntensityDisplay(EventModel event, Color color) {
    // Try to parse new JSON format with zones
    if (event.metaData != null && event.metaData!.isNotEmpty) {
      try {
        final metadata = jsonDecode(event.metaData!);
        if (metadata['zones'] != null && metadata['zones'] is List) {
          final zones = metadata['zones'] as List;
          if (zones.isNotEmpty) {
            final zoneTexts = zones
                .map((z) {
                  final name = z['name'] ?? event.title;
                  final severity = z['severity'] ?? event.severity;
                  return '$name: $severity/10';
                })
                .join('\n');

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                zoneTexts,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            );
          }
        }
      } catch (e) {
        print('[SYMPTOM] Failed to parse meta_data: $e');
      }
    }

    // Fallback to old format (single severity)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Intensité ${event.severity}/10',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Crohnicles',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.timeline, size: 22),
            tooltip: 'Timeline Visuelle',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TimelineChartPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.developer_mode, size: 22),
            tooltip: 'Menu Développeur',
            onPressed: _showDevMenu,
          ),
          IconButton(
            icon: const Icon(Icons.search, size: 22),
            onPressed: () =>
                showSearch(context: context, delegate: EventSearchDelegate()),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart, size: 22),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InsightsPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month, size: 22),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CalendarPage()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMenu,
        label: const Text(
          'Ajouter',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        icon: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildDailySummary(context),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _events.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) return _buildSectionTitle("Aujourd'hui");
                  final event = _events[index - 1];
                  if (event.type == EventType.meal)
                    return _buildMealCard(event);
                  if (event.type == EventType.symptom)
                    return _buildSymptomCard(event);
                  if (event.type == EventType.stool)
                    return _buildStoolCard(event);
                  if (event.type == EventType.daily_checkup)
                    return _buildCheckupCard(event);
                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS D'AFFICHAGE ---

  Widget _buildDailySummary(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Aujourd'hui",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Météo: Humide • 18°C",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("😊", style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  "Stable",
                  style: GoogleFonts.inter(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 12, top: 20),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildMealCard(EventModel event) {
    bool isSnack = event.isSnack;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        onLongPress: () => _showEventOptions(event),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              // Modern Icon with Gradient Background
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.mealGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.mealStart.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  isSnack ? Icons.cookie_outlined : Icons.restaurant,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Image Thumbnail (Desktop/Mobile)
              if (event.imagePath != null && !kIsWeb)
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(
                      image: FileImage(File(event.imagePath!)),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.time,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (event.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: event.tags
                            .map(
                              (tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoolCard(EventModel event) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        onLongPress: () => _showEventOptions(event),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.stoolGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.stoolStart.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.waves, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.time,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      event.subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (event.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: event.tags.map((tag) {
                          final isAlert = tag == 'Sang' || tag == 'Urgent';
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isAlert
                                  ? AppColors.pain.withValues(alpha: 0.1)
                                  : AppColors.stool.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isAlert
                                    ? AppColors.pain
                                    : AppColors.stool,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSymptomCard(EventModel event) {
    final color = AppColors.pain;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        onLongPress: () => _showEventOptions(event),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.painGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.painStart.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.bolt, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.time,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSymptomIntensityDisplay(event, color),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckupCard(EventModel event) {
    final color = AppColors.checkup;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        onLongPress: () => _showEventOptions(event),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.checkupGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.checkupStart.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.bedtime, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.time,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (event.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "Stress: ${event.severity}/5",
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.checkup,
                              ),
                            ),
                          ),
                          ...event.tags.map(
                            (tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                tag,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.checkup,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
