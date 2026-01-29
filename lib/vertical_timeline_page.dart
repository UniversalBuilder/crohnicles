import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:math' show max;
import 'event_model.dart';
import 'database_helper.dart';
import 'app_theme.dart';

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
          style: GoogleFonts.poppins(
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
          ? const Center(
              child: Text(
                'Aucun événement dans les 7 derniers jours',
                style: TextStyle(color: Colors.grey),
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
    final totalMinutes = lastEventTime.difference(firstEventTime).inMinutes;

    // Minimum spacing to avoid overlap (increased for clarity)
    const minSpacing = 180.0; // pixels
    final pixelsPerMinute = max(
      0.8,
      minSpacing / (totalMinutes / _events.length),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final centerX = constraints.maxWidth / 2;

        return Container(
          // Simple clean background
          color: Colors.grey.shade50,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: (_events.length * minSpacing) + 200,
                  child: Stack(
                    children: [
                      // Central axis line (thicker, with glow effect)
                      Positioned(
                        left: centerX - 3,
                        top: 20,
                        bottom: 20,
                        child: Container(
                          width: 6,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.indigo.shade200,
                                Colors.indigo.shade400,
                                Colors.indigo.shade200,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.indigo.withValues(alpha: 0.3),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Date graduations on axis
                      ..._buildDateGraduations(
                        centerX,
                        firstEventTime,
                        lastEventTime,
                        pixelsPerMinute,
                      ),

                      // Correlation lines (ComfyUI-style bezier curves)
                      ..._buildCorrelationLines(
                        centerX,
                        firstEventTime,
                        pixelsPerMinute,
                      ),

                      // Event cards (node-style)
                      ..._buildEventCards(
                        centerX,
                        firstEventTime,
                        pixelsPerMinute,
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

  List<Widget> _buildDateGraduations(
    double centerX,
    DateTime firstEventTime,
    DateTime lastEventTime,
    double pixelsPerMinute,
  ) {
    final graduations = <Widget>[];

    // Generate one graduation per day
    final currentDate = DateTime(
      firstEventTime.year,
      firstEventTime.month,
      firstEventTime.day,
    );
    final endDate = DateTime(
      lastEventTime.year,
      lastEventTime.month,
      lastEventTime.day,
    ).add(const Duration(days: 1));

    DateTime gradDate = currentDate;
    while (gradDate.isBefore(endDate)) {
      final yPosition = _calculateYPosition(
        gradDate,
        firstEventTime,
        pixelsPerMinute,
      );

      // Day separator line
      graduations.add(
        Positioned(
          left: centerX - 50,
          top: yPosition,
          child: Row(
            children: [
              Container(width: 40, height: 2, color: Colors.grey.shade300),
              Container(width: 20, height: 2, color: Colors.transparent),
              Container(width: 40, height: 2, color: Colors.grey.shade300),
            ],
          ),
        ),
      );

      // Date label
      graduations.add(
        Positioned(
          left: centerX + 110,
          top: yPosition - 15,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              DateFormat('EEE d MMM', 'fr_FR').format(gradDate),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ),
      );

      gradDate = gradDate.add(const Duration(days: 1));
    }

    return graduations;
  }

  List<Widget> _buildCorrelationLines(
    double centerX,
    DateTime firstEventTime,
    double pixelsPerMinute,
  ) {
    final lines = <Widget>[];

    _correlations.forEach((symptomId, mealIds) {
      final symptom = _events.firstWhere(
        (e) => e.id?.toString() == symptomId,
        orElse: () => _events.first,
      );

      final symptomTime = DateTime.parse(symptom.dateTime);
      final symptomY = _calculateYPosition(
        symptomTime,
        firstEventTime,
        pixelsPerMinute,
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
          pixelsPerMinute,
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
                color: Colors.red.withValues(alpha: 0.25),
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
    double pixelsPerMinute,
  ) {
    final cards = <Widget>[];

    for (int i = 0; i < _events.length; i++) {
      final event = _events[i];
      final eventTime = DateTime.parse(event.dateTime);
      final yPosition = _calculateYPosition(
        eventTime,
        firstEventTime,
        pixelsPerMinute,
      );

      // Timestamp on central axis
      cards.add(
        Positioned(
          left: centerX - 40,
          top: yPosition + 30,
          child: Container(
            width: 80,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              DateFormat('HH:mm').format(eventTime),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ),
      );

      // Event card
      if (event.type == EventType.meal) {
        // Meals on the right
        cards.add(
          Positioned(
            left: centerX + 50,
            top: yPosition + 10,
            child: _buildMealCard(event),
          ),
        );
      } else {
        // Symptoms and stools on the left
        cards.add(
          Positioned(
            right: centerX + 50,
            top: yPosition + 10,
            child: event.type == EventType.symptom
                ? _buildSymptomCard(event)
                : _buildStoolCard(event),
          ),
        );
      }
    }

    return cards;
  }

  double _calculateYPosition(
    DateTime eventTime,
    DateTime firstEventTime,
    double pixelsPerMinute,
  ) {
    final minutesDiff = eventTime.difference(firstEventTime).inMinutes;
    return 50 + (minutesDiff * pixelsPerMinute);
  }

  Widget _buildMealCard(EventModel event) {
    return GestureDetector(
      onTap: () => _showEventDetail(event),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          gradient: AppColors.mealGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: AppColors.mealStart.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: Icon(
          event.isSnack ? Icons.cookie : Icons.restaurant,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildSymptomCard(EventModel event) {
    return GestureDetector(
      onTap: () => _showEventDetail(event),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          gradient: AppColors.painGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: AppColors.painStart.withValues(alpha: 0.5),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: const Icon(Icons.bolt, color: Colors.white, size: 32),
      ),
    );
  }

  Widget _buildStoolCard(EventModel event) {
    return GestureDetector(
      onTap: () => _showEventDetail(event),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: AppColors.stoolGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.stoolStart.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.waves, color: Colors.white, size: 28),
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

    // Inner highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
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
