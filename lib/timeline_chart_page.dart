import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'event_model.dart';
import 'database_helper.dart';
import 'app_theme.dart';
import 'models/timeline_event_group.dart';
import 'event_detail_page.dart';

class TimelineChartPage extends StatefulWidget {
  const TimelineChartPage({super.key});

  @override
  State<TimelineChartPage> createState() => _TimelineChartPageState();
}

class _TimelineChartPageState extends State<TimelineChartPage> {
  int _selectedDays = 7;
  List<TimelineEventGroup> _groups = [];
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final db = DatabaseHelper();
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: _selectedDays));

    final allEvents = await db.getEvents();
    final events = allEvents.map((e) => EventModel.fromMap(e)).where((e) {
      try {
        final eventDate = DateTime.parse(e.dateTime);
        return eventDate.isAfter(startDate) && eventDate.isBefore(now);
      } catch (e) {
        return false;
      }
    }).toList();

    // Group events by time buckets
    final bucketDuration = _getBucketDuration();
    final Map<DateTime, TimelineEventGroup> groupMap = {};

    for (var event in events) {
      final eventTime = DateTime.parse(event.dateTime);
      final bucket = _getBucket(eventTime, bucketDuration);

      if (!groupMap.containsKey(bucket)) {
        groupMap[bucket] = TimelineEventGroup(
          bucketTime: bucket,
          meals: [],
          symptoms: [],
          stools: [],
        );
      }

      switch (event.type) {
        case EventType.meal:
          groupMap[bucket]!.meals.add(event);
          break;
        case EventType.symptom:
          groupMap[bucket]!.symptoms.add(event);
          break;
        case EventType.stool:
          groupMap[bucket]!.stools.add(event);
          break;
        default:
          break;
      }
    }

    final sortedGroups = groupMap.values.toList()
      ..sort((a, b) => a.bucketTime.compareTo(b.bucketTime));

    setState(() {
      _groups = sortedGroups;
      _isLoading = false;
    });

    // Scroll to end after loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Duration _getBucketDuration() {
    switch (_selectedDays) {
      case 1:
        return const Duration(hours: 1);
      case 7:
        return const Duration(hours: 6);
      case 30:
        return const Duration(days: 1);
      default:
        return const Duration(hours: 6);
    }
  }

  DateTime _getBucket(DateTime time, Duration bucketSize) {
    final epoch = DateTime(1970);
    final diff = time.difference(epoch);
    final bucketCount = diff.inMicroseconds ~/ bucketSize.inMicroseconds;
    return epoch.add(
      Duration(microseconds: bucketCount * bucketSize.inMicroseconds),
    );
  }

  String _formatBucketLabel(DateTime bucket) {
    switch (_selectedDays) {
      case 1:
        return DateFormat('HH:mm').format(bucket);
      case 7:
        return DateFormat('EEE HH:mm').format(bucket);
      case 30:
        return DateFormat('dd/MM').format(bucket);
      default:
        return DateFormat('dd/MM HH:mm').format(bucket);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Timeline Visuelle',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.date_range),
            onSelected: (days) {
              setState(() => _selectedDays = days);
              _loadData();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 1, child: Text('24 heures')),
              const PopupMenuItem(value: 7, child: Text('7 jours')),
              const PopupMenuItem(value: 30, child: Text('30 jours')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.timeline, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun événement sur cette période',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                _buildLegend(),
                _buildStatsBar(),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: _groups.length,
                    itemBuilder: (context, index) {
                      return _buildTimeSlice(index);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildLegendItem(Icons.restaurant, 'Repas', AppColors.mealStart),
          _buildLegendItem(Icons.favorite, 'Douleurs', AppColors.painStart),
          _buildLegendItem(
            Icons.analytics_outlined,
            'Selles',
            AppColors.stoolStart,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    final totalMeals = _groups.fold<int>(0, (sum, g) => sum + g.meals.length);
    final totalSymptoms = _groups.fold<int>(
      0,
      (sum, g) => sum + g.symptoms.length,
    );
    final totalStools = _groups.fold<int>(0, (sum, g) => sum + g.stools.length);
    final correlations = _groups
        .asMap()
        .entries
        .where((e) => _hasCorrelation(e.key))
        .length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[50]!, Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatChip(totalMeals, 'repas', AppColors.mealStart),
          _buildStatChip(totalSymptoms, 'douleurs', AppColors.painStart),
          _buildStatChip(totalStools, 'selles', AppColors.stoolStart),
          if (correlations > 0)
            _buildStatChip(
              correlations,
              'alertes',
              Colors.red.shade600,
              icon: Icons.warning_amber_rounded,
            ),
        ],
      ),
    );
  }

  Widget _buildStatChip(
    int count,
    String label,
    Color color, {
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 14, color: color)
          else
            Text(
              '$count',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildTimeSlice(int index) {
    final group = _groups[index];
    final hasCorrelation = _hasCorrelation(index);

    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 6),
      child: Column(
        children: [
          // Time label
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: BoxDecoration(
              color: hasCorrelation ? Colors.red.shade50 : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: hasCorrelation
                  ? Border.all(color: Colors.red.shade300, width: 1.5)
                  : null,
            ),
            child: Column(
              children: [
                Text(
                  _formatBucketLabel(group.bucketTime),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: hasCorrelation
                        ? Colors.red.shade700
                        : Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
                if (hasCorrelation)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: 12,
                      color: Colors.red.shade700,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Meals track
          SizedBox(
            height: 80,
            child: _buildTrack(
              group.meals,
              AppColors.mealGradient,
              Icons.restaurant,
              Icons.local_cafe,
            ),
          ),

          const SizedBox(height: 6),

          // Symptoms track
          SizedBox(height: 100, child: _buildSymptomsTrack(group.symptoms)),

          const SizedBox(height: 6),

          // Stools track
          SizedBox(
            height: 70,
            child: _buildTrack(
              group.stools,
              AppColors.stoolGradient,
              Icons.analytics_outlined,
              null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrack(
    List<EventModel> events,
    LinearGradient gradient,
    IconData mainIcon,
    IconData? altIcon,
  ) {
    if (events.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[200]!, width: 1),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showEventsDialog(events),
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient.scale(0.25),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: gradient.colors.first.withValues(alpha: 0.6),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withValues(alpha: 0.15),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                events.first.isSnack && altIcon != null ? altIcon : mainIcon,
                color: gradient.colors.first,
                size: 20,
              ),
              if (events.length > 1)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: gradient.colors.first.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${events.length}',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: gradient.colors.first,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSymptomsTrack(List<EventModel> symptoms) {
    if (symptoms.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[200]!, width: 1),
        ),
      );
    }

    final maxSeverity = symptoms.map((e) => e.severity).reduce(math.max);
    final avgSeverity =
        symptoms.map((e) => e.severity).reduce((a, b) => a + b) /
        symptoms.length;
    final intensityScale = math.min(1.0, maxSeverity / 8);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showEventsDialog(symptoms),
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppColors.painGradient.scale(0.2 + intensityScale * 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.painStart.withValues(
                alpha: 0.4 + intensityScale * 0.4,
              ),
              width: maxSeverity >= 7 ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.painStart.withValues(
                  alpha: 0.1 + intensityScale * 0.2,
                ),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                maxSeverity >= 7 ? Icons.favorite : Icons.favorite_border,
                color: AppColors.painStart,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                avgSeverity.toStringAsFixed(1),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.painStart,
                  height: 1,
                ),
              ),
              Text(
                '/10',
                style: GoogleFonts.inter(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: AppColors.painStart.withValues(alpha: 0.7),
                ),
              ),
              if (symptoms.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.painStart.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '×${symptoms.length}',
                      style: GoogleFonts.inter(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: AppColors.painStart,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool _hasCorrelation(int index) {
    if (index == 0) return false;

    final currentGroup = _groups[index];

    // Check if this bucket has severe symptoms
    if (currentGroup.symptoms.isEmpty) return false;
    final hasSevereSymptom = currentGroup.symptoms.any((s) => s.severity >= 6);
    if (!hasSevereSymptom) return false;

    // Check previous buckets for trigger meals (2-24h window)
    final bucketDuration = _getBucketDuration();

    // Calculate how many buckets represent 2-24h
    final minBucketsBack =
        2 ~/ (bucketDuration.inHours > 0 ? bucketDuration.inHours : 1);
    final maxBucketsBack =
        24 ~/ (bucketDuration.inHours > 0 ? bucketDuration.inHours : 1);

    for (
      int i = math.max(0, index - maxBucketsBack);
      i < math.max(0, index - minBucketsBack);
      i++
    ) {
      if (_groups[i].meals.isNotEmpty) {
        // Check if any meal has trigger tags
        final hasTrigger = _groups[i].meals.any((meal) {
          final tagsLower = meal.tags.map((t) => t.toLowerCase()).toList();
          return tagsLower.contains('gras') ||
              tagsLower.contains('gluten') ||
              tagsLower.contains('lactose') ||
              tagsLower.contains('alcool') ||
              tagsLower.contains('épicé');
        });
        if (hasTrigger) return true;
      }
    }

    return false;
  }

  void _showEventsDialog(List<EventModel> events) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                '${events.length} événement${events.length > 1 ? 's' : ''}',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final event = events[index];
                  final eventTime = DateTime.parse(event.dateTime);

                  IconData icon;
                  Color color;

                  switch (event.type) {
                    case EventType.meal:
                      icon = event.isSnack
                          ? Icons.local_cafe
                          : Icons.restaurant;
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
                    trailing:
                        event.type == EventType.symptom && event.severity > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
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
}
