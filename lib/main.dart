import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:provider/provider.dart';

import 'package:crohnicles/app_theme.dart';
import 'package:crohnicles/themes/app_theme.dart' as themes;
import 'package:crohnicles/providers/theme_provider.dart';
import 'package:crohnicles/utils/responsive_wrapper.dart';
import 'package:crohnicles/utils/platform_utils.dart';
import 'package:crohnicles/calendar_page.dart';
import 'package:crohnicles/database_helper.dart';
import 'package:crohnicles/event_model.dart';
import 'package:crohnicles/event_search_delegate.dart';
import 'package:crohnicles/insights_page.dart';
import 'package:crohnicles/meal_composer_dialog.dart';
import 'package:crohnicles/risk_assessment_card.dart';
import 'package:crohnicles/services/background_service.dart';
import 'package:crohnicles/services/context_service.dart';
import 'package:crohnicles/services/log_service.dart';
import 'package:crohnicles/settings_page.dart';
import 'package:crohnicles/stool_entry_dialog.dart';
import 'package:crohnicles/symptom_dialog.dart';
import 'package:crohnicles/vertical_timeline_page.dart';
import 'package:crohnicles/ml/model_manager.dart';
import 'package:crohnicles/models/context_model.dart';
import 'package:crohnicles/about_page.dart';
import 'package:crohnicles/methodology_page.dart';
import 'package:crohnicles/logs_page.dart';
import 'package:crohnicles/ml/model_status_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  final log = LogService();
  log.log('[Main] App starting...');

  // Initialize Background Service (Weather automation)
  if (PlatformUtils.isMobile) {
    try {
      await BackgroundService.initialize();
      await BackgroundService.registerPeriodicTask();
      log.log('[Main] Background service initialized');
    } catch (e) {
      log.log("[Main] Failed to init background service: $e");
    }
  }

  // Initialize date formatting for French locale (fixes LocaleDataException)
  await initializeDateFormatting('fr_FR', null);

  // Initialisation de la base de données pour le Web et Desktop
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider()..loadThemeMode(),
      child: const MyApp(),
    ),
  );
}

// --- MODÈLES ---
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) => MaterialApp(
        title: 'Crohnicles',
        theme: themes.AppTheme.light(),
        darkTheme: themes.AppTheme.dark(),
        themeMode: themeProvider.themeMode,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('fr', 'FR'),
        ],
        home: const ResponsiveWrapper(child: TimelinePage()),
        debugShowCheckedModeBanner: false,
        routes: {
          '/about': (context) => const AboutPage(),
          '/methodology': (context) => const MethodologyPage(),
          '/logs': (context) => const LogsPage(),
          '/model-status': (context) => const ModelStatusPage(),
          '/insights': (context) => const InsightsPage(),
          '/calendar': (context) => const CalendarPage(),
          '/settings': (context) => const SettingsPage(),
        },
      ),
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

  Future<void> _deleteEvent(int id) async {
    final dbHelper = DatabaseHelper();
    await dbHelper.deleteEvent(id);
    _loadEvents();
  }

  void _showMealDialog() async {
    debugPrint('[MAIN] Opening meal dialog');
    final result = await showDialog(
      context: context,
      builder: (context) => const MealComposerDialog(),
    );

    debugPrint('[MAIN] Meal dialog result: $result');
    if (result != null && result is Map) {
      // Get isSnack from result
      final bool resultIsSnack = result['is_snack'] as bool? ?? false;
      final List<dynamic> foodsList = result['foods'] as List<dynamic>? ?? [];

      // Generate title
      final List<String> foodNames = foodsList
          .map(
            (f) => f is Map ? f['name'] as String? ?? 'Aliment' : f.toString(),
          )
          .toList();

      String title;
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

      final DateTime? timestamp = result['timestamp'] as DateTime?;

      _addEvent(
        EventType.meal,
        title,
        isSnack: resultIsSnack,
        tags: result['tags'] as List<String>? ?? [],
        metaData: jsonEncode({'foods': foodsList}),
        customDate: timestamp,
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
                        Theme.of(
                          context,
                        ).colorScheme.surface.withValues(alpha: 0.95),
                        Theme.of(context).colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.90),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.3),
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
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                        .withValues(alpha: 0.8),
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  Icons.bedtime,
                                  size: 28,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  "Bilan du Soir",
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer,
                                        letterSpacing: -0.5,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(fontWeight: FontWeight.w600),
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
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(fontWeight: FontWeight.w600),
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
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(fontWeight: FontWeight.w600),
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
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: isSelected
                                                    ? Colors.white
                                                    : Colors.black87,
                                                fontWeight: FontWeight.w600,
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
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(fontWeight: FontWeight.w600),
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
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
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
            customDate: result['timestamp'] as DateTime?,
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
    DateTime? customDate,
  }) async {
    debugPrint(
      '➕ Adding event: type=$type, title=$title, severity=$severity, isSnack=$isSnack, date=$customDate',
    );
    final now = customDate ?? DateTime.now();

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
    debugPrint('[MAIN] Event saved successfully');

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
      debugPrint('[MAIN] Generating risk assessment...');
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
      debugPrint('[MAIN] Error generating risk assessment: $e');
      // Don't block the user flow if ML fails
    }
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(
              top: BorderSide(color: colorScheme.outlineVariant, width: 1.5),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.onSurface.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
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
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
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
      final DateTime date = result['timestamp'] as DateTime? ?? DateTime.now();

      List<String> tags = [];
      if (isUrgent) tags.add("Urgent");
      if (hasBlood) tags.add("Sang");

      final newEvent = EventModel(
        type: EventType.stool,
        dateTime: date.toIso8601String(),
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
          // Parse foods - result['foods'] is now a List<Map>
          final List<dynamic> foodsList =
              result['foods'] as List<dynamic>? ?? [];
          final List<String> foodNames = foodsList
              .map(
                (f) =>
                    f is Map ? f['name'] as String? ?? 'Aliment' : f.toString(),
              )
              .toList();

          String title;
          bool isSnack = result['is_snack'] ?? false;

          if (foodNames.isEmpty) {
            title = isSnack ? 'Encas' : 'Repas';
          } else if (foodNames.length == 1) {
            title = foodNames[0];
          } else if (foodNames.length == 2) {
            title = '${foodNames[0]} + ${foodNames[1]}';
          } else {
            title = isSnack
                ? 'Encas de ${foodNames.length} aliments'
                : 'Repas de ${foodNames.length} aliments';
          }

          final updatedEvent = EventModel(
            type: EventType.meal,
            dateTime: event.dateTime, // Keep original time
            title: title,
            subtitle: '', // Empty subtitle
            isSnack: isSnack,
            tags: List<String>.from(result['tags'] ?? []),
            severity: 0,
            metaData: jsonEncode({'foods': foodsList}),
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
          if (!mounted) return;

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

  void _showMealDetail(EventModel event) {
    // Parse foods from meta_data
    List<dynamic> foods = [];
    if (event.metaData != null && event.metaData!.isNotEmpty) {
      try {
        final metadata = jsonDecode(event.metaData!);

        if (metadata is List) {
          foods = metadata;
        } else if (metadata is Map && metadata.containsKey('foods')) {
          var f = metadata['foods'];
          if (f is String) {
            try {
              f = jsonDecode(f);
            } catch (e) {
              debugPrint('[MEAL DETAIL] Error decoding inner foods: $e');
            }
          }
          if (f is List) {
            foods = f;
          }
        }
      } catch (e) {
        debugPrint('[MEAL DETAIL] Failed to parse meta_data: $e');
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                event.isSnack ? Icons.cookie : Icons.restaurant,
                color: AppColors.mealGradient.colors.first,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  event.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Event time and subtitle
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      event.time,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    if (event.subtitle.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '•',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        event.subtitle,
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                // Foods list
                if (foods.isEmpty)
                  const Text('Aucun aliment enregistré')
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aliments (${foods.length})',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...foods.map((foodJson) {
                        final name = foodJson['name'] ?? 'Inconnu';
                        final brand = foodJson['brand'];
                        final imageUrl = foodJson['imageUrl'];
                        final hasImage =
                            imageUrl != null && imageUrl.toString().isNotEmpty;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Food image
                              if (hasImage)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    imageUrl,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: AppColors
                                              .mealGradient
                                              .colors
                                              .first
                                              .withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.fastfood,
                                          size: 20,
                                          color: AppColors
                                              .mealGradient
                                              .colors
                                              .first,
                                        ),
                                      );
                                    },
                                  ),
                                )
                              else
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    gradient: AppColors.mealGradient.scale(0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.fastfood,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                              const SizedBox(width: 12),
                              // Food details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (brand != null &&
                                        brand.toString().isNotEmpty)
                                      Text(
                                        brand,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _editEvent(event);
              },
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Modifier'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mealGradient.colors.first,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
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
        debugPrint('[SYMPTOM] Failed to parse meta_data: $e');
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
            icon: const Icon(Icons.settings, size: 22),
            tooltip: 'Paramètres',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ).then((_) => _loadEvents()),
          ),
          IconButton(
            icon: const Icon(Icons.search, size: 22),
            onPressed: () =>
                showSearch(context: context, delegate: EventSearchDelegate()),
          ),
          IconButton(
            icon: const Icon(Icons.timeline_outlined, size: 22),
            tooltip: 'Timeline',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VerticalTimelinePage()),
            ),
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
                itemCount: _getDisplayItems().length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) return _buildSectionTitle("Aujourd'hui");
                  final item = _getDisplayItems()[index - 1];

                  if (item is EventModel) {
                    // Single event display
                    if (item.type == EventType.meal) {
                      return _buildMealCard(item);
                    }
                    if (item.type == EventType.symptom) {
                      return _buildSymptomCard(item);
                    }
                    if (item.type == EventType.stool) {
                      return _buildStoolCard(item);
                    }
                    if (item.type == EventType.daily_checkup) {
                      return _buildCheckupCard(item);
                    }
                  } else if (item is List<EventModel>) {
                    // Grouped events
                    final firstEvent = item.first;
                    if (firstEvent.type == EventType.daily_checkup) {
                      return _buildGroupedCheckupCard(item);
                    } else if (firstEvent.type == EventType.symptom) {
                      return _buildGroupedSymptomCard(item);
                    }
                  }

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

  /// Groups consecutive weather checkups (hourly) and symptoms by timestamp
  List<dynamic> _getDisplayItems() {
    final List<dynamic> items = [];
    List<EventModel>? currentWeatherGroup;
    final Map<String, List<EventModel>> symptomGroups = {};

    // First pass: group symptoms by rounded timestamp (to the minute)
    for (final event in _events) {
      if (event.type == EventType.symptom) {
        final timestamp = event.dateTime.substring(0, 16); // YYYY-MM-DDTHH:MM
        symptomGroups[timestamp] ??= [];
        symptomGroups[timestamp]!.add(event);
      }
    }

    // Second pass: build display items with grouped weather and symptoms
    for (int i = 0; i < _events.length; i++) {
      final event = _events[i];

      // Check if this is a weather checkup (auto-generated)
      final isWeather =
          event.type == EventType.daily_checkup &&
          event.title.contains('Météo');

      if (isWeather) {
        // Start or add to weather group
        currentWeatherGroup ??= [];
        currentWeatherGroup.add(event);

        // Check if next event is also weather, if not, close the group
        if (i == _events.length - 1 ||
            !(_events[i + 1].type == EventType.daily_checkup &&
                _events[i + 1].title.contains('Météo'))) {
          // Close group
          if (currentWeatherGroup.length == 1) {
            items.add(currentWeatherGroup.first);
          } else {
            items.add(List<EventModel>.from(currentWeatherGroup));
          }
          currentWeatherGroup = null;
        }
      } else if (event.type == EventType.symptom) {
        final timestamp = event.dateTime.substring(0, 16);
        final group = symptomGroups[timestamp]!;
        
        // Only add the group once (check if this is the first occurrence)
        if (group.first.id == event.id) {
          if (group.length == 1) {
            items.add(group.first);
          } else {
            items.add(List<EventModel>.from(group));
          }
        }
      } else {
        // Other events (meal, stool, checkup) - add directly
        items.add(event);
      }
    }

    return items;
  }

  Widget _buildDailySummary(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FutureBuilder<Map<String, dynamic>?>(
      future: DatabaseHelper().getTodayWeather(),
      builder: (context, snapshot) {
        String weatherText = "Météo non disponible";
        if (snapshot.hasData && snapshot.data != null) {
          final tempRaw = snapshot.data!['temperature'];
          final humidityRaw = snapshot.data!['humidity'];

          if (tempRaw != null) {
            final temp = tempRaw is num
                ? tempRaw.toDouble()
                : double.tryParse(tempRaw.toString()) ?? 0.0;
            weatherText = "${temp.toStringAsFixed(1)}°C";

            if (humidityRaw != null) {
              final humidity = humidityRaw is num
                  ? humidityRaw.toDouble()
                  : double.tryParse(humidityRaw.toString()) ?? 0.0;
              weatherText += " • ${humidity.toStringAsFixed(0)}% humidité";
            }
          }
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: 1,
            ),
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
              Flexible(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Aujourd'hui",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      weatherText,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("😊", style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          "Stable",
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 12, top: 20),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurfaceVariant,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildMealCard(EventModel event) {
    bool isSnack = event.isSnack;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showMealDetail(event),
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
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: colorScheme.onSurface,
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
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
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      event.subtitle,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
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
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: colorScheme.onSurface,
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
    final colorScheme = Theme.of(context).colorScheme;

    // Check if this is a weather checkup
    final isWeather = event.title.contains('Météo');
    final icon = isWeather ? Icons.wb_cloudy : Icons.bedtime;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
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
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.time,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: colorScheme.onSurface,
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

  /// Builds a grouped card for consecutive weather checkups
  Widget _buildGroupedCheckupCard(List<EventModel> events) {
    final colorScheme = Theme.of(context).colorScheme;

    // Get time range
    final firstTime = events.first.time;
    final lastTime = events.last.time;
    final timeRange = firstTime == lastTime
        ? firstTime
        : '$firstTime - $lastTime';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
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
                child: const Icon(
                  Icons.wb_cloudy,
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
                      timeRange,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${events.length} relevés météo',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.checkup.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${events.length}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.checkup,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedSymptomCard(List<EventModel> events) {
    final colorScheme = Theme.of(context).colorScheme;
    final time = events.first.time;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                child: const Icon(
                  Icons.bolt,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.painStart.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${events.length}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.painStart,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${events.length} symptôme${events.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Liste des symptômes
                    ...events.map((event) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: colorScheme.onSurfaceVariant,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onLongPress: () => _showEventOptions(event),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Expanded(
                                    child: Text(
                                      event.title,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colorScheme.onSurface,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildSymptomIntensityDisplay(event, AppColors.pain),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
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

