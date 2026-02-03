import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import 'event_model.dart';
import 'database_helper.dart';
import 'event_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crohnicles/themes/app_gradients.dart';

/// Extension for optional chaining
extension LetExtension<T> on T? {
  R? let<R>(R Function(T) block) {
    if (this != null) {
      return block(this as T);
    }
    return null;
  }
}

/// Vertical timeline view with central axis, meals on right, symptoms/stools on left
/// Shows correlation lines between related events (>30% correlation)
class VerticalTimelinePage extends StatefulWidget {
  const VerticalTimelinePage({super.key});

  @override
  State<VerticalTimelinePage> createState() => _VerticalTimelinePageState();
}

class _VerticalTimelinePageState extends State<VerticalTimelinePage> {
  List<EventModel> _events = [];
  Map<String, List<String>> _correlations = {}; // eventId → correlated meal IDs
  bool _isLoading = true;
  
  // New: Interactive states
  Map<String, bool> _expandedEvents = {};
  Set<String> _selectedForAnalysis = {};
  bool _analysisMode = false;
  String? _hoveredEventId;
  Map<String, Map<String, dynamic>> _weatherData = {}; // eventId → weather data

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadAnalysisSelection();
  }
  
  Future<void> _loadAnalysisSelection() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIds = prefs.getStringList('timeline_analysis_selection') ?? [];
    setState(() {
      _selectedForAnalysis = savedIds.toSet();
    });
  }
  
  Future<void> _saveAnalysisSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'timeline_analysis_selection',
      _selectedForAnalysis.toList(),
    );
  }
  
  void _toggleAnalysisMode() {
    setState(() {
      _analysisMode = !_analysisMode;
      if (!_analysisMode) {
        // Clear expanded states when exiting analysis mode
        _expandedEvents.clear();
      }
    });
  }
  
  void _clearAnalysisSelection() {
    setState(() {
      _selectedForAnalysis.clear();
    });
    _saveAnalysisSelection();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sélection effacée')),
    );
  }
  
  void _toggleEventSelection(String eventId) {
    setState(() {
      if (_selectedForAnalysis.contains(eventId)) {
        _selectedForAnalysis.remove(eventId);
      } else {
        _selectedForAnalysis.add(eventId);
      }
    });
    _saveAnalysisSelection();
  }

  Future<void> _loadData() async {
    final dbHelper = DatabaseHelper();

    // Load last 7 days of events
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    final eventsMap = await dbHelper.getEvents();
    final allEvents = eventsMap.map((e) => EventModel.fromMap(e)).toList();

    // Filter events from last 7 days (include meals, symptoms, stools, and critical daily_checkups)
    final recentEvents = allEvents.where((e) {
      final eventDate = DateTime.parse(e.dateTime);
      if (!eventDate.isAfter(weekAgo) || !eventDate.isBefore(now)) {
        return false;
      }
      
      // Include daily_checkup only if critical (stress ≥8 or sleep ≤3)
      if (e.type == EventType.daily_checkup) {
        try {
          final metaData = jsonDecode(e.metaData ?? '{}') as Map<String, dynamic>;
          final stress = (metaData['stress_level'] as num?)?.toInt() ?? 0;
          final sleep = (metaData['sleep_quality'] as num?)?.toInt() ?? 10;
          return stress >= 8 || sleep <= 3;
        } catch (_) {
          return false;
        }
      }
      
      return true;
    }).toList();

    // Sort chronologically (oldest first for vertical layout)
    recentEvents.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    
    // Extract weather data from events
    final weatherData = <String, Map<String, dynamic>>{};
    for (final event in recentEvents) {
      if (event.contextData != null && event.contextData!.isNotEmpty) {
        try {
          final context = jsonDecode(event.contextData!) as Map<String, dynamic>;
          if (context.containsKey('temperature') || context.containsKey('weather')) {
            weatherData[event.id?.toString() ?? ''] = {
              'temperature': (context['temperature'] as String?)?.let((t) => double.tryParse(t)),
              'humidity': (context['humidity'] as String?)?.let((h) => double.tryParse(h)),
              'pressure': (context['pressure'] as String?)?.let((p) => double.tryParse(p)),
              'condition': context['weather'] as String?,
            };
          }
        } catch (_) {
          // Ignore parsing errors
        }
      }
    }

    // Calculate correlations (symptoms within 4-8h after meals)
    final correlations = <String, List<String>>{};

    for (final symptom in recentEvents.where(
      (e) => e.type == EventType.symptom && e.severity >= 5,
    )) {
      final symptomTime = DateTime.parse(symptom.dateTime);
      final correlatedMeals = <String>[];

      for (final meal in recentEvents.where((e) => e.type == EventType.meal)) {
        final mealTime = DateTime.parse(meal.dateTime);
        final hoursDiff = symptomTime.difference(mealTime).inHours;

        // Symptom occurred 4-8 hours after meal
        if (hoursDiff >= 4 && hoursDiff <= 8) {
          correlatedMeals.add(meal.id?.toString() ?? '');
        }
      }

      if (correlatedMeals.isNotEmpty && symptom.id != null) {
        correlations[symptom.id.toString()] = correlatedMeals;
      }
    }

    setState(() {
      _events = recentEvents;
      _correlations = correlations;
      _weatherData = weatherData;
      _isLoading = false;
      
      // Clean up selected events that are no longer in the timeline
      _selectedForAnalysis.removeWhere(
        (id) => !recentEvents.any((e) => e.id?.toString() == id),
      );
    });
    
    // Show toast if events were restored
    if (_selectedForAnalysis.isNotEmpty) {
      Future.delayed(Duration.zero, () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${_selectedForAnalysis.length} événement(s) sélectionné(s) pour analyse',
              ),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Timeline Verticale',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          if (_analysisMode && _selectedForAnalysis.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Effacer sélection',
              onPressed: _clearAnalysisSelection,
            ),
          IconButton(
            icon: Icon(_analysisMode ? Icons.analytics : Icons.analytics_outlined),
            tooltip: _analysisMode ? 'Quitter mode analyse' : 'Mode analyse',
            onPressed: _toggleAnalysisMode,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
          ? Center(
              child: Text(
                'Aucun événement dans les 7 derniers jours',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : _buildVerticalTimeline(),
    );
  }

  Widget _buildVerticalTimeline() {
    // Calculate time span for proportional spacing
    if (_events.isEmpty) return const SizedBox.shrink();

    final firstEventTime = DateTime.parse(_events.first.dateTime);
    final lastEventTime = DateTime.parse(_events.last.dateTime);
    final totalHours = lastEventTime.difference(firstEventTime).inHours;

    // Adaptive spacing: 45px per hour (reduced from 60px for 25% space gain)
    const pixelsPerHour = 45.0;
    final totalHeight = (totalHours * pixelsPerHour) + 200;

    return LayoutBuilder(
      builder: (context, constraints) {
        final centerX = constraints.maxWidth / 2;
        final isMobile = constraints.maxWidth < 600;
        final colorScheme = Theme.of(context).colorScheme;

        return Container(
          color: colorScheme.surface,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: totalHeight,
                  child: Stack(
                    children: [
                      // Alternating time bands (every 6 hours)
                      ..._buildTimeBands(
                        firstEventTime,
                        lastEventTime,
                        pixelsPerHour,
                        constraints.maxWidth,
                      ),

                      // Central axis line
                      Positioned(
                        left: centerX - 2,
                        top: 20,
                        bottom: 20,
                        child: Container(
                          width: 4,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                colorScheme.primary.withValues(alpha: 0.6),
                                colorScheme.primary,
                                colorScheme.primary.withValues(alpha: 0.6),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.2,
                                ),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Hour graduations
                      ..._buildHourGraduations(
                        centerX,
                        firstEventTime,
                        lastEventTime,
                        pixelsPerHour,
                        isMobile,
                      ),

                      // Correlation lines
                      ..._buildCorrelationLines(
                        centerX,
                        firstEventTime,
                        pixelsPerHour,
                      ),

                      // Event cards
                      ..._buildEventCards(
                        centerX,
                        firstEventTime,
                        pixelsPerHour,
                        isMobile,
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

  List<Widget> _buildTimeBands(
    DateTime firstEventTime,
    DateTime lastEventTime,
    double pixelsPerHour,
    double width,
  ) {
    final bands = <Widget>[];
    final startHour = DateTime(
      firstEventTime.year,
      firstEventTime.month,
      firstEventTime.day,
      firstEventTime.hour,
    );

    DateTime currentTime = startHour;
    int bandIndex = 0;

    while (currentTime.isBefore(lastEventTime.add(const Duration(hours: 1)))) {
      final yPosition = _calculateYPosition(
        currentTime,
        firstEventTime,
        pixelsPerHour,
      );
      final nextTime = currentTime.add(const Duration(hours: 6));
      final nextY = _calculateYPosition(
        nextTime,
        firstEventTime,
        pixelsPerHour,
      );

      final colorScheme = Theme.of(context).colorScheme;
      
      // Calculate average temperature for this time band
      final avgTemp = _getAverageTemperatureForPeriod(
        currentTime,
        nextTime,
      );
      
      // Color based on temperature: blue (<12°C) → neutral (12-20°C) → orange (>25°C)
      Color bandColor;
      if (avgTemp != null) {
        if (avgTemp < 12) {
          bandColor = Colors.blue.withValues(alpha: 0.05);
        } else if (avgTemp > 25) {
          bandColor = Colors.orange.withValues(alpha: 0.05);
        } else {
          bandColor = bandIndex % 2 == 0
              ? colorScheme.surfaceContainerLowest
              : colorScheme.surfaceContainer;
        }
      } else {
        bandColor = bandIndex % 2 == 0
            ? colorScheme.surfaceContainerLowest
            : colorScheme.surfaceContainer;
      }

      bands.add(
        Positioned(
          left: 0,
          top: yPosition,
          child: Container(
            width: width,
            height: nextY - yPosition,
            color: bandColor,
          ),
        ),
      );

      currentTime = nextTime;
      bandIndex++;
    }

    return bands;
  }

  List<Widget> _buildHourGraduations(
    double centerX,
    DateTime firstEventTime,
    DateTime lastEventTime,
    double pixelsPerHour,
    bool isMobile,
  ) {
    final graduations = <Widget>[];
    final colorScheme = Theme.of(
      WidgetsBinding.instance.rootElement!,
    ).colorScheme;
    final startHour = DateTime(
      firstEventTime.year,
      firstEventTime.month,
      firstEventTime.day,
      firstEventTime.hour,
    );

    DateTime currentTime = startHour;
    DateTime? lastDayLabel;

    while (currentTime.isBefore(lastEventTime.add(const Duration(hours: 1)))) {
      final yPosition = _calculateYPosition(
        currentTime,
        firstEventTime,
        pixelsPerHour,
      );
      final isNewDay =
          lastDayLabel == null || currentTime.day != lastDayLabel.day;
      final showThisHour = !isMobile || currentTime.hour % 2 == 0;

      if (showThisHour) {
        // Hour marker line
        graduations.add(
          Positioned(
            left: centerX - 30,
            top: yPosition,
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: isNewDay ? 3 : 1.5,
                  color: isNewDay
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Container(
                  width: 20,
                  height: isNewDay ? 3 : 1.5,
                  color: isNewDay
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        );

        // Hour label
        graduations.add(
          Positioned(
            left: centerX - (isMobile ? 35 : 45),
            top: yPosition - 12,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 6 : 8,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isNewDay
                      ? colorScheme.primary.withValues(alpha: 0.3)
                      : colorScheme.outlineVariant.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Text(
                DateFormat('HH:mm').format(currentTime),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: isMobile ? 8 : 9,
                  fontWeight: isNewDay ? FontWeight.w600 : FontWeight.w400,
                  color: (isNewDay
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant).withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        );
      }

      // Day label on the right
      if (isNewDay) {
        graduations.add(
          Positioned(
            right: isMobile ? 8 : 20,
            top: yPosition - 15,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 8 : 12,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.9),
                    colorScheme.primary,
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                DateFormat('EEE d MMM', 'fr_FR').format(currentTime),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: isMobile ? 10 : 11,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        );
        lastDayLabel = currentTime;
      }

      currentTime = currentTime.add(const Duration(hours: 1));
    }

    return graduations;
  }

  List<Widget> _buildCorrelationLines(
    double centerX,
    DateTime firstEventTime,
    double pixelsPerHour,
  ) {
    final lines = <Widget>[];
    final colorScheme = Theme.of(context).colorScheme;

    _correlations.forEach((symptomId, mealIds) {
      final symptom = _events.firstWhere(
        (e) => e.id?.toString() == symptomId,
        orElse: () => _events.first,
      );

      final symptomTime = DateTime.parse(symptom.dateTime);
      final symptomY = _calculateYPosition(
        symptomTime,
        firstEventTime,
        pixelsPerHour,
      );

      for (final mealId in mealIds) {
        final meal = _events.firstWhere(
          (e) => e.id?.toString() == mealId,
          orElse: () => _events.first,
        );

        final mealTime = DateTime.parse(meal.dateTime);
        final mealY = _calculateYPosition(
          mealTime,
          firstEventTime,
          pixelsPerHour,
        );
        
        // Determine visibility based on mode and selection
        double lineOpacity = 0.0; // Default: invisible
        bool showLabel = false;
        
        if (_analysisMode) {
          // In analysis mode: show correlations between selected events
          if (_selectedForAnalysis.contains(symptomId) && 
              _selectedForAnalysis.contains(mealId)) {
            lineOpacity = 0.8;
            showLabel = true;
          }
        } else {
          // Normal mode: show correlations for expanded event
          if (_expandedEvents[symptomId] == true || 
              _expandedEvents[mealId] == true) {
            lineOpacity = 0.8;
            showLabel = true;
          } else if (_hoveredEventId == symptomId || 
                     _hoveredEventId == mealId) {
            lineOpacity = 0.3; // Dotted preview on hover
          }
        }
        
        if (lineOpacity > 0) {
          lines.add(
            Positioned(
              left: 0,
              top: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: lineOpacity,
                child: CustomPaint(
                  size: Size(centerX * 2, symptomY + 100),
                  painter: _CorrelationLinePainter(
                    startX: centerX - 70, // Left edge of symptom card
                    startY: symptomY + 25,
                    endX: centerX + 70, // Right edge of meal card
                    endY: mealY + 25,
                    color: colorScheme.error,
                    opacity: lineOpacity,
                    showLabel: showLabel,
                  ),
                ),
              ),
            ),
          );
        }
      }
    });

    return lines;
  }

  /// Creates clusters of events that are within 20 minutes of each other on the same side
  /// Returns a map with 'clusters' (List<List<EventModel>>) and 'singles' (List<EventModel>)
  Map<String, dynamic> _createEventClusters() {
    final List<List<EventModel>> clusters = [];
    final List<EventModel> singles = [];
    final List<EventModel> processed = [];

    // Sort events by time first
    final sortedEvents = List<EventModel>.from(_events)
      ..sort((a, b) => DateTime.parse(a.dateTime).compareTo(DateTime.parse(b.dateTime)));

    for (int i = 0; i < sortedEvents.length; i++) {
      if (processed.contains(sortedEvents[i])) continue;

      final event = sortedEvents[i];
      final eventTime = DateTime.parse(event.dateTime);
      final eventSide = event.type == EventType.meal ? 'right' : 'left';
      final cluster = <EventModel>[event];
      processed.add(event);

      // Find all events within 20 minutes on the SAME SIDE
      for (int j = i + 1; j < sortedEvents.length; j++) {
        if (processed.contains(sortedEvents[j])) continue;

        final otherEvent = sortedEvents[j];
        final otherTime = DateTime.parse(otherEvent.dateTime);
        final otherSide = otherEvent.type == EventType.meal ? 'right' : 'left';
        final diff = otherTime.difference(eventTime).inMinutes.abs();

        // Only cluster events on the same side within 20 minutes
        if (diff <= 20 && eventSide == otherSide) {
          cluster.add(otherEvent);
          processed.add(otherEvent);
        } else if (diff > 20) {
          // Stop looking if we're past the time window
          break;
        }
      }

      // If 2 or more events, create a cluster, otherwise add to singles
      if (cluster.length >= 2) {
        clusters.add(cluster);
      } else {
        singles.addAll(cluster);
      }
    }

    return {'clusters': clusters, 'singles': singles};
  }

  List<Widget> _buildEventCards(
    double centerX,
    DateTime firstEventTime,
    double pixelsPerHour,
    bool isMobile,
  ) {
    final compactCards = <Widget>[];
    final expandedCards = <Widget>[];
    final cardWidth = 120.0;
    final compactHeight = 50.0;
    final expandedHeight = 200.0; // Taller for expanded state
    final horizontalOffset = 70.0;

    // Get clusters and singles
    final clustersData = _createEventClusters();
    final List<List<EventModel>> clusters = clustersData['clusters'];
    final List<EventModel> singles = clustersData['singles'];

    // Track Y positions to detect overlaps
    final Map<String, List<double>> sidePositions = {
      'left': [],
      'right': [],
    };

    // Add cluster cards first
    for (final cluster in clusters) {
      // Use the first event's time as the cluster time
      final clusterTime = DateTime.parse(cluster.first.dateTime);
      var yPosition = _calculateYPosition(
        clusterTime,
        firstEventTime,
        pixelsPerHour,
      );

      // Determine side based on majority of events
      final mealCount = cluster.where((e) => e.type == EventType.meal).length;
      final side = mealCount > cluster.length / 2 ? 'right' : 'left';

      // Check for overlaps and adjust position
      var offset = 0.0;
      for (final existingY in sidePositions[side]!) {
        if ((yPosition - existingY).abs() < compactHeight + 5) {
          offset += 15.0;
        }
      }
      yPosition += offset;
      sidePositions[side]!.add(yPosition);

      // Clusters are always compact (not individually expandable)
      Widget clusterWidget;
      if (side == 'right') {
        clusterWidget = Positioned(
          left: centerX + horizontalOffset,
          top: yPosition - (compactHeight / 2),
          child: _buildClusterCard(cluster, cardWidth, compactHeight, side),
        );
      } else {
        clusterWidget = Positioned(
          right: centerX + horizontalOffset,
          top: yPosition - (compactHeight / 2),
          child: _buildClusterCard(cluster, cardWidth, compactHeight, side),
        );
      }
      compactCards.add(clusterWidget);
    }

    // Add single event cards
    for (final event in singles) {
      final eventTime = DateTime.parse(event.dateTime);
      var yPosition = _calculateYPosition(
        eventTime,
        firstEventTime,
        pixelsPerHour,
      );

      // Determine side
      final side = event.type == EventType.meal ? 'right' : 'left';
      
      // Check if card is expanded
      final eventId = event.id?.toString() ?? '';
      final isExpanded = _expandedEvents[eventId] ?? false;
      final currentHeight = isExpanded ? expandedHeight : compactHeight;
      
      // Check for overlaps and adjust position
      var offset = 0.0;
      for (final existingY in sidePositions[side]!) {
        if ((yPosition - existingY).abs() < currentHeight + 5) {
          offset += 15.0;
        }
      }
      yPosition += offset;
      sidePositions[side]!.add(yPosition);
      
      Widget cardWidget;
      // Event card
      if (event.type == EventType.meal) {
        // Meals on the right
        cardWidget = Positioned(
          left: centerX + horizontalOffset,
          top: yPosition - (currentHeight / 2),
          child: _buildMealCard(event, cardWidth, currentHeight),
        );
      } else {
        // Symptoms and stools on the left
        cardWidget = Positioned(
          right: centerX + horizontalOffset,
          top: yPosition - (currentHeight / 2),
          child: event.type == EventType.symptom
              ? _buildSymptomCard(event, cardWidth, currentHeight)
              : _buildStoolCard(event, cardWidth * 0.8, currentHeight * 0.8),
        );
      }
      
      // Add to appropriate list based on expanded state
      if (isExpanded) {
        expandedCards.add(cardWidget);
      } else {
        compactCards.add(cardWidget);
      }
    }

    // Return compact cards first, then expanded cards (so expanded are on top in the Stack)
    return [...compactCards, ...expandedCards];
  }

  /// Builds a cluster card showing multiple events
  Widget _buildClusterCard(
    List<EventModel> cluster,
    double width,
    double height,
    String side,
  ) {
    // Determine accent color based on event types in cluster
    Color accentColor;
    if (cluster.any((e) => e.type == EventType.symptom)) {
      accentColor = Colors.red.shade400;
    } else if (cluster.any((e) => e.type == EventType.meal)) {
      accentColor = Colors.green.shade400;
    } else {
      accentColor = Colors.amber.shade400;
    }

    // Get first 3 event icons to preview
    final previewIcons = cluster.take(3).map((event) {
      if (event.type == EventType.meal) {
        return Icons.restaurant;
      } else if (event.type == EventType.symptom) {
        return Icons.local_hospital;
      } else {
        return Icons.wc;
      }
    }).toList();

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredEventId = 'cluster_${cluster.first.id}'),
      onExit: (_) => setState(() => _hoveredEventId = null),
      child: GestureDetector(
        onTap: () => _showClusterDialog(cluster),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: _hoveredEventId == 'cluster_${cluster.first.id}'
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 30,
                      spreadRadius: 3,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 5),
                    ),
                  ],
          ),
          child: Stack(
            children: [
              // Accent bar
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      bottomLeft: Radius.circular(8),
                    ),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 8, top: 8, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Stacked preview icons
                    Expanded(
                      child: SizedBox(
                        width: 50,
                        child: Stack(
                          children: [
                            for (int i = 0; i < previewIcons.length; i++)
                              Positioned(
                                left: i * 12.0,
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surface,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    previewIcons[i],
                                    size: 12,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // +N badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '+${cluster.length}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: accentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
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
    );
  }

  /// Shows a dialog listing all events in a cluster
  void _showClusterDialog(List<EventModel> cluster) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${cluster.length} événements'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: cluster.length,
            itemBuilder: (context, index) {
              final event = cluster[index];
              final time = DateFormat('HH:mm').format(DateTime.parse(event.dateTime));
              
              IconData icon;
              String label;
              if (event.type == EventType.meal) {
                icon = Icons.restaurant;
                label = 'Repas';
              } else if (event.type == EventType.symptom) {
                icon = Icons.local_hospital;
                label = 'Symptôme';
              } else {
                icon = Icons.wc;
                label = 'Selle';
              }

              return ListTile(
                leading: Icon(icon),
                title: Text('$label à $time'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EventDetailPage(event: event),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  double? _getAverageTemperatureForPeriod(DateTime start, DateTime end) {
    final temperatures = <double>[];
    
    for (final event in _events) {
      final eventTime = DateTime.parse(event.dateTime);
      if (eventTime.isAfter(start) && eventTime.isBefore(end)) {
        final weatherInfo = _weatherData[event.id?.toString() ?? ''];
        final temp = weatherInfo?['temperature'] as double?;
        if (temp != null) {
          temperatures.add(temp);
        }
      }
    }
    
    if (temperatures.isEmpty) return null;
    return temperatures.reduce((a, b) => a + b) / temperatures.length;
  }

  double _calculateYPosition(
    DateTime eventTime,
    DateTime firstEventTime,
    double pixelsPerHour,
  ) {
    final hoursDiff = eventTime.difference(firstEventTime).inHours;
    final minutesFraction =
        (eventTime.difference(firstEventTime).inMinutes % 60) / 60.0;
    return 50 + ((hoursDiff + minutesFraction) * pixelsPerHour);
  }

  Widget _buildMealCard(EventModel event, double width, double height) {
    final eventId = event.id?.toString() ?? '';
    final isExpanded = _expandedEvents[eventId] ?? false;
    final isSelected = _selectedForAnalysis.contains(eventId);
    final isHovered = _hoveredEventId == eventId;
    final weatherInfo = _weatherData[eventId];
    
    return _buildUnifiedEventCard(
      event: event,
      width: 120,
      height: isExpanded ? 200 : height,
      leftBorderColor: Colors.orange,
      icon: event.isSnack ? Icons.cookie : Icons.restaurant_menu,
      weatherInfo: weatherInfo,
      isExpanded: isExpanded,
      isSelected: isSelected,
      isHovered: isHovered,
    );
  }

  Widget _buildSymptomCard(EventModel event, double width, double height) {
    final eventId = event.id?.toString() ?? '';
    final isExpanded = _expandedEvents[eventId] ?? false;
    final isSelected = _selectedForAnalysis.contains(eventId);
    final isHovered = _hoveredEventId == eventId;
    final weatherInfo = _weatherData[eventId];
    
    return _buildUnifiedEventCard(
      event: event,
      width: 120,
      height: isExpanded ? 200 : height,
      leftBorderColor: Colors.red,
      icon: Icons.bolt,
      weatherInfo: weatherInfo,
      isExpanded: isExpanded,
      isSelected: isSelected,
      isHovered: isHovered,
    );
  }

  Widget _buildStoolCard(EventModel event, double width, double height) {
    final eventId = event.id?.toString() ?? '';
    final isExpanded = _expandedEvents[eventId] ?? false;
    final isSelected = _selectedForAnalysis.contains(eventId);
    final isHovered = _hoveredEventId == eventId;
    final weatherInfo = _weatherData[eventId];
    
    return _buildUnifiedEventCard(
      event: event,
      width: 120,
      height: isExpanded ? 200 : height,
      leftBorderColor: Colors.blue,
      icon: Icons.waves,
      weatherInfo: weatherInfo,
      isExpanded: isExpanded,
      isSelected: isSelected,
      isHovered: isHovered,
    );
  }
  
  Widget _buildUnifiedEventCard({
    required EventModel event,
    required double width,
    required double height,
    required Color leftBorderColor,
    required IconData icon,
    Map<String, dynamic>? weatherInfo,
    bool isExpanded = false,
    bool isSelected = false,
    bool isHovered = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final eventId = event.id?.toString() ?? '';
    
    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredEventId = eventId),
      onExit: (_) => setState(() => _hoveredEventId = null),
      child: GestureDetector(
        onTap: () {
          if (_analysisMode) {
            _toggleEventSelection(eventId);
          } else {
            setState(() {
              _expandedEvents[eventId] = !isExpanded;
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: width,
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                // Main card background
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    border: Border.all(
                      color: isSelected 
                        ? colorScheme.primary
                        : colorScheme.outlineVariant.withValues(alpha: 0.5),
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      if (isExpanded) ...[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 40,
                          offset: const Offset(0, 12),
                          spreadRadius: 5,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 25,
                          offset: const Offset(0, 6),
                          spreadRadius: 3,
                        ),
                      ] else ...[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                          spreadRadius: 2,
                        ),
                        if (isHovered)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 30,
                            offset: const Offset(0, 8),
                            spreadRadius: 3,
                          ),
                      ],
                    ],
                  ),
                  child: isExpanded
                      ? _buildExpandedCardContent(event, weatherInfo, icon, colorScheme)
                      : _buildCompactCardContent(event, weatherInfo, icon, colorScheme, isSelected),
                ),
                // Left color accent bar
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: leftBorderColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomLeft: Radius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildCompactCardContent(
    EventModel event,
    Map<String, dynamic>? weatherInfo,
    IconData icon,
    ColorScheme colorScheme,
    bool isSelected,
  ) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0), // Compensate for left bar
          child: Row(
            children: [
              // Icon (28px for better visibility)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  icon,
                  size: 28,
                  color: colorScheme.onSurface,
                ),
              ),
              // Title (truncated)
              Expanded(
                child: Text(
                  event.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
        // Weather badge (top-right corner)
        if (weatherInfo != null)
          Positioned(
            top: 2,
            right: 2,
            child: _buildWeatherBadge(weatherInfo),
          ),
        // Checkbox for analysis mode
        if (_analysisMode)
          Positioned(
            top: 2,
            left: 8, // Adjusted for left bar
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: isSelected ? colorScheme.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected ? colorScheme.primary : colorScheme.outline,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(3),
              ),
              child: isSelected
                  ? Icon(Icons.check, size: 12, color: colorScheme.onPrimary)
                  : null,
            ),
          ),
      ],
    );
  }
  
  Widget _buildExpandedCardContent(
    EventModel event,
    Map<String, dynamic>? weatherInfo,
    IconData icon,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
          // Header with icon and title
          Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.onSurface),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  event.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          // Tags
          if (event.tags.isNotEmpty)
            Wrap(
              spacing: 3,
              runSpacing: 2,
              children: event.tags.take(2).map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  tag,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 9,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              )).toList(),
            ),
          const SizedBox(height: 3),
          // Weather info
          if (weatherInfo != null) ...[
            _buildDetailedWeatherInfo(weatherInfo, colorScheme),
            const SizedBox(height: 3),
          ],
          // Severity for symptoms
          if (event.type == EventType.symptom)
            Text(
              'Sévérité: ${event.severity}/10',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 9,
              ),
            ),
          const Spacer(),
          // Details button
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EventDetailPage(event: event),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  'Détails >',
                  style: TextStyle(fontSize: 9, color: colorScheme.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
  
  Widget _buildWeatherBadge(Map<String, dynamic> weatherInfo) {
    final temp = weatherInfo['temperature'] as double?;
    final condition = weatherInfo['condition'] as String?;
    
    String emoji = '🌡️';
    if (temp != null) {
      if (temp < 12) {
        emoji = '❄️';
      } else if (temp > 25) {
        emoji = '🔥';
      }
    }
    if (condition == 'rainy' || condition == 'rain') {
      emoji = '💧';
    }
    
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 8),
        ),
      ),
    );
  }
  
  Widget _buildDetailedWeatherInfo(
    Map<String, dynamic> weatherInfo,
    ColorScheme colorScheme,
  ) {
    final temp = weatherInfo['temperature'] as double?;
    final humidity = weatherInfo['humidity'] as double?;
    final condition = weatherInfo['condition'] as String?;
    
    return Row(
      children: [
        if (temp != null) ...[
          Icon(Icons.thermostat, size: 10, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 2),
          Text(
            '${temp.toStringAsFixed(1)}°C',
            style: TextStyle(fontSize: 9, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 6),
        ],
        if (humidity != null) ...[
          Icon(Icons.water_drop, size: 10, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 2),
          Text(
            '${humidity.toStringAsFixed(0)}%',
            style: TextStyle(fontSize: 9, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }

  void _showEventDetail(EventModel event) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(event.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Date: ${DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(DateTime.parse(event.dateTime))}',
              ),
              const SizedBox(height: 8),
              if (event.tags.isNotEmpty) ...[
                const Text(
                  'Tags:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Wrap(
                  spacing: 6,
                  children: event.tags.map((tag) {
                    return Chip(label: Text(tag), padding: EdgeInsets.zero);
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],
              if (event.type == EventType.meal && event.metaData != null) ...[
                const Text(
                  'Aliments:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                ..._buildFoodList(event.metaData!),
              ],
              if (event.type == EventType.symptom) ...[
                Text('Sévérité: ${event.severity}/10'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFoodList(String metaData) {
    try {
      final data = jsonDecode(metaData);
      final foods = data['foods'] as List?;
      if (foods == null) return [const Text('Aucun aliment')];

      return foods.map((food) {
        final name = food['name'] ?? 'Inconnu';
        return Padding(
          padding: const EdgeInsets.only(left: 8, top: 4),
          child: Text('• $name'),
        );
      }).toList();
    } catch (e) {
      return [const Text('Erreur de chargement')];
    }
  }
}

/// Custom painter for curved correlation lines between events
class _CorrelationLinePainter extends CustomPainter {
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final Color color;
  final double opacity;
  final bool showLabel;

  _CorrelationLinePainter({
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.color,
    this.opacity = 1.0,
    this.showLabel = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Simplified ComfyUI-inspired connection lines (no glow for cleaner look)

    // Main line only (stroke 2px for subtlety)
    final mainPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0.8 * opacity),
          Colors.pink.withValues(alpha: 0.6 * opacity),
        ],
      ).createShader(Rect.fromLTWH(startX, startY, endX - startX, endY - startY))
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Bezier curve path (horizontal control points for ComfyUI-style)
    final path = Path();
    path.moveTo(startX, startY);

    // Horizontal bezier (ComfyUI connection style) - curve toward center
    final horizontalDistance = (endX - startX).abs();
    final controlOffset = horizontalDistance * 0.5; // 50% of distance for smoother curve

    path.cubicTo(
      startX + controlOffset,
      startY, // First control point (horizontal from start, going right)
      endX - controlOffset,
      endY, // Second control point (horizontal to end, coming from left)
      endX,
      endY, // End point
    );

    // Draw simplified line (no glow for cleaner look)
    canvas.drawPath(path, mainPaint);

    // Draw connection dots at ends
    final dotPaint = Paint()
      ..color = color.withValues(alpha: 0.8 * opacity)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(startX, startY), 3, dotPaint);
    canvas.drawCircle(Offset(endX, endY), 3, dotPaint);
    
    // Draw label "4-8h" if showLabel and enough space
    if (showLabel && horizontalDistance > 100) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: '4-8h',
          style: TextStyle(
            color: color.withValues(alpha: 0.9 * opacity),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      
      // Position at midpoint of curve
      final midX = (startX + endX) / 2;
      final midY = (startY + endY) / 2;
      
      // Background blur effect
      final bgPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      
      final bgRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(midX, midY),
          width: textPainter.width + 8,
          height: textPainter.height + 4,
        ),
        const Radius.circular(4),
      );
      
      canvas.drawRRect(bgRect, bgPaint);
      textPainter.paint(
        canvas,
        Offset(midX - textPainter.width / 2, midY - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CorrelationLinePainter oldDelegate) {
    return oldDelegate.opacity != opacity || oldDelegate.showLabel != showLabel;
  }
}
