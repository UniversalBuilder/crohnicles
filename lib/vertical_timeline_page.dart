import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'event_model.dart';
import 'database_helper.dart';
import 'app_theme.dart';
import 'package:crohnicles/themes/app_gradients.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final dbHelper = DatabaseHelper();

    // Load last 7 days of events
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    final eventsMap = await dbHelper.getEvents();
    final allEvents = eventsMap.map((e) => EventModel.fromMap(e)).toList();

    // Filter events from last 7 days
    final recentEvents = allEvents.where((e) {
      final eventDate = DateTime.parse(e.dateTime);
      return eventDate.isAfter(weekAgo) && eventDate.isBefore(now);
    }).toList();

    // Sort chronologically (oldest first for vertical layout)
    recentEvents.sort((a, b) => a.dateTime.compareTo(b.dateTime));

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
      _isLoading = false;
    });
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
          'Timeline Verticale',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
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

    // Adaptive spacing: 60px per hour (2h = 120px) - reduced for better density
    const pixelsPerHour = 60.0;
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

      final colorScheme = Theme.of(
        WidgetsBinding.instance.rootElement!,
      ).colorScheme;
      final color = bandIndex % 2 == 0
          ? colorScheme.surfaceContainerLowest
          : colorScheme.surfaceContainer;

      bands.add(
        Positioned(
          left: 0,
          top: yPosition,
          child: Container(
            width: width,
            height: nextY - yPosition,
            color: color,
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
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isNewDay
                      ? colorScheme.primary.withValues(alpha: 0.6)
                      : colorScheme.outline,
                  width: isNewDay ? 1.5 : 1,
                ),
              ),
              child: Text(
                DateFormat('HH:mm').format(currentTime),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: isMobile ? 9 : 10,
                  fontWeight: isNewDay ? FontWeight.w700 : FontWeight.w500,
                  color: isNewDay
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
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
    final colorScheme = Theme.of(
      WidgetsBinding.instance.rootElement!,
    ).colorScheme;

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

        // Draw curved line from meal (right) to symptom (left)
        lines.add(
          Positioned(
            left: 0,
            top: 0,
            child: CustomPaint(
              size: Size(centerX * 2, symptomY + 100),
              painter: _CorrelationLinePainter(
                startX: centerX + 78, // Right side (meal icon center)
                startY: mealY + 38,
                endX: centerX - 78, // Left side (symptom icon center)
                endY: symptomY + 38,
                color: colorScheme.error.withValues(alpha: 0.2),
              ),
            ),
          ),
        );
      }
    });

    return lines;
  }

  List<Widget> _buildEventCards(
    double centerX,
    DateTime firstEventTime,
    double pixelsPerHour,
    bool isMobile,
  ) {
    final cards = <Widget>[];
    final cardWidth = isMobile ? 60.0 : 70.0;
    final cardHeight = isMobile ? 60.0 : 70.0;
    final horizontalOffset = isMobile ? 35.0 : 50.0;

    for (int i = 0; i < _events.length; i++) {
      final event = _events[i];
      final eventTime = DateTime.parse(event.dateTime);
      final yPosition = _calculateYPosition(
        eventTime,
        firstEventTime,
        pixelsPerHour,
      );

      // Event card
      if (event.type == EventType.meal) {
        // Meals on the right
        cards.add(
          Positioned(
            left: centerX + horizontalOffset,
            top: yPosition - (cardHeight / 2),
            child: _buildMealCard(event, cardWidth, cardHeight),
          ),
        );
      } else {
        // Symptoms and stools on the left
        cards.add(
          Positioned(
            right: centerX + horizontalOffset,
            top: yPosition - (cardHeight / 2),
            child: event.type == EventType.symptom
                ? _buildSymptomCard(event, cardWidth, cardHeight)
                : _buildStoolCard(event, cardWidth * 0.8, cardHeight * 0.8),
          ),
        );
      }
    }

    return cards;
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
    final colorScheme = Theme.of(
      WidgetsBinding.instance.rootElement!,
    ).colorScheme;
    final brightness = Theme.of(
      WidgetsBinding.instance.rootElement!,
    ).brightness;

    return GestureDetector(
      onTap: () => _showEventDetail(event),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: AppGradients.forEventType('meal', brightness),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.onPrimary, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(
          event.isSnack ? Icons.cookie : Icons.restaurant,
          color: colorScheme.onPrimary,
          size: width * 0.45,
        ),
      ),
    );
  }

  Widget _buildSymptomCard(EventModel event, double width, double height) {
    final colorScheme = Theme.of(
      WidgetsBinding.instance.rootElement!,
    ).colorScheme;
    final brightness = Theme.of(
      WidgetsBinding.instance.rootElement!,
    ).brightness;

    return GestureDetector(
      onTap: () => _showEventDetail(event),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: AppGradients.forEventType('symptom', brightness),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.onPrimary, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: colorScheme.error.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 3),
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(
          Icons.bolt,
          color: colorScheme.onPrimary,
          size: width * 0.45,
        ),
      ),
    );
  }

  Widget _buildStoolCard(EventModel event, double width, double height) {
    final colorScheme = Theme.of(
      WidgetsBinding.instance.rootElement!,
    ).colorScheme;
    final brightness = Theme.of(
      WidgetsBinding.instance.rootElement!,
    ).brightness;

    return GestureDetector(
      onTap: () => _showEventDetail(event),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: AppGradients.forEventType('stool', brightness),
          shape: BoxShape.circle,
          border: Border.all(color: colorScheme.onPrimary, width: 2),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.waves,
          color: colorScheme.onPrimary,
          size: width * 0.5,
        ),
      ),
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

  _CorrelationLinePainter({
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ComfyUI-inspired connection lines with glow effect

    // Outer glow
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    // Main line
    final mainPaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Inner highlight (use same color as main with reduced alpha for consistency)
    final highlightPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Bezier curve path (horizontal control points for ComfyUI-style)
    final path = Path();
    path.moveTo(startX, startY);

    // Horizontal bezier (ComfyUI connection style)
    final horizontalDistance = (endX - startX).abs();
    final controlOffset = horizontalDistance * 0.4; // 40% of distance

    path.cubicTo(
      startX + controlOffset,
      startY, // First control point (horizontal from start)
      endX - controlOffset,
      endY, // Second control point (horizontal to end)
      endX,
      endY, // End point
    );

    // Draw in layers: glow → main → highlight
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, mainPaint);
    canvas.drawPath(path, highlightPaint);

    // Draw connection dots at ends
    final dotPaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(startX, startY), 4, dotPaint);
    canvas.drawCircle(Offset(endX, endY), 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
