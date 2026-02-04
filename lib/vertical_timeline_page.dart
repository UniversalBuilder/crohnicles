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

  // New: Day-based view states
  final Map<String, bool> _expandedDays = {}; // date → isExpanded
  EventModel? _selectedEvent; // For detail panel
  Map<String, Map<String, dynamic>> _weatherData = {}; // eventId → weather data
  Map<String, List<EventModel>> _eventsByDay = {}; // date → events list

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

    // Filter events from last 7 days (include meals, symptoms, stools, and critical daily_checkups)
    final recentEvents = allEvents.where((e) {
      final eventDate = DateTime.parse(e.dateTime);
      if (!eventDate.isAfter(weekAgo) || !eventDate.isBefore(now)) {
        return false;
      }

      // Include daily_checkup only if critical (stress ≥8 or sleep ≤3)
      if (e.type == EventType.daily_checkup) {
        try {
          final metaData =
              jsonDecode(e.metaData ?? '{}') as Map<String, dynamic>;
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
          final context =
              jsonDecode(event.contextData!) as Map<String, dynamic>;
          if (context.containsKey('temperature') ||
              context.containsKey('weather')) {
            weatherData[event.id?.toString() ?? ''] = {
              'temperature': (context['temperature'] as String?)?.let(
                (t) => double.tryParse(t),
              ),
              'humidity': (context['humidity'] as String?)?.let(
                (h) => double.tryParse(h),
              ),
              'pressure': (context['pressure'] as String?)?.let(
                (p) => double.tryParse(p),
              ),
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

      // Group events by day
      _eventsByDay = _groupEventsByDay(recentEvents);
    });
  }

  /// Groups events by day (date string YYYY-MM-DD)
  Map<String, List<EventModel>> _groupEventsByDay(List<EventModel> events) {
    final grouped = <String, List<EventModel>>{};

    for (final event in events) {
      final date = DateTime.parse(event.dateTime);
      final dateKey = DateFormat('yyyy-MM-dd').format(date);

      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(event);
    }

    // Sort events within each day by time
    for (final dayEvents in grouped.values) {
      dayEvents.sort(
        (a, b) =>
            DateTime.parse(a.dateTime).compareTo(DateTime.parse(b.dateTime)),
      );
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Timeline', style: Theme.of(context).textTheme.titleLarge),
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
    if (_eventsByDay.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    // Sort days in reverse chronological order (most recent first)
    final sortedDays = _eventsByDay.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Container(
      color: colorScheme.surface,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sortedDays.length,
        itemBuilder: (context, index) {
          final dateKey = sortedDays[index];
          final dayEvents = _eventsByDay[dateKey]!;
          final isExpanded = _expandedDays[dateKey] ?? false;

          return _buildDayCard(dateKey, dayEvents, isExpanded, colorScheme);
        },
      ),
    );
  }

  /// Builds a collapsible day card
  Widget _buildDayCard(
    String dateKey,
    List<EventModel> dayEvents,
    bool isExpanded,
    ColorScheme colorScheme,
  ) {
    final date = DateTime.parse(dateKey);
    final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == dateKey;
    final dayLabel = isToday
        ? 'Aujourd\'hui'
        : DateFormat('EEEE d MMMM', 'fr_FR').format(date);

    // Count events by type
    final mealCount = dayEvents.where((e) => e.type == EventType.meal).length;
    final symptomCount = dayEvents
        .where((e) => e.type == EventType.symptom)
        .length;
    final stoolCount = dayEvents.where((e) => e.type == EventType.stool).length;

    // Check if day has correlations
    final hasCorrelations = dayEvents.any((e) {
      final eventId = e.id?.toString() ?? '';
      return _correlations.containsKey(eventId) ||
          _correlations.values.any((list) => list.contains(eventId));
    });

    // Get weather summary for the day
    final dayWeather = _getAverageWeatherForDay(dayEvents);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: isExpanded ? 8 : 2,
        color: colorScheme.surfaceContainerHigh,
        child: Column(
          children: [
            // Day header (always visible)
            InkWell(
              onTap: () {
                setState(() {
                  _expandedDays[dateKey] = !isExpanded;
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Expand icon
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    // Date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dayLabel,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isToday ? colorScheme.primary : null,
                                ),
                          ),
                          const SizedBox(height: 4),
                          // Event counts
                          Wrap(
                            spacing: 12,
                            children: [
                              if (mealCount > 0)
                                _buildCountChip(
                                  Icons.restaurant_menu,
                                  mealCount,
                                  Colors.green,
                                ),
                              if (symptomCount > 0)
                                _buildCountChip(
                                  Icons.warning_amber,
                                  symptomCount,
                                  Colors.red,
                                ),
                              if (stoolCount > 0)
                                _buildCountChip(
                                  Icons.water_drop,
                                  stoolCount,
                                  Colors.blue,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Weather & correlation indicators
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (dayWeather != null) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.thermostat,
                                size: 16,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${dayWeather['temperature']?.toStringAsFixed(0)}°C',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                        if (hasCorrelations)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.link, size: 14, color: Colors.red),
                                const SizedBox(width: 4),
                                Text(
                                  'Corrélations',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Expanded content (hourly timeline)
            if (isExpanded) _buildDayDetailTimeline(dayEvents, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildCountChip(IconData icon, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// Get average weather for all events in a day
  Map<String, dynamic>? _getAverageWeatherForDay(List<EventModel> dayEvents) {
    final temperatures = <double>[];
    String? condition;

    for (final event in dayEvents) {
      final eventId = event.id?.toString() ?? '';
      final weather = _weatherData[eventId];
      if (weather != null) {
        final temp = weather['temperature'] as double?;
        if (temp != null) temperatures.add(temp);
        condition ??= weather['condition'] as String?;
      }
    }

    if (temperatures.isEmpty) return null;

    return {
      'temperature': temperatures.reduce((a, b) => a + b) / temperatures.length,
      'condition': condition,
    };
  }

  /// Builds the detailed hourly timeline for an expanded day
  Widget _buildDayDetailTimeline(
    List<EventModel> dayEvents,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Column(
        children: dayEvents.map((event) {
          return _buildEventRow(event, colorScheme);
        }).toList(),
      ),
    );
  }

  /// Builds a single event row in the day detail
  Widget _buildEventRow(EventModel event, ColorScheme colorScheme) {
    final time = DateFormat('HH:mm').format(DateTime.parse(event.dateTime));
    final eventId = event.id?.toString() ?? '';
    final isSelected = _selectedEvent?.id == event.id;
    final hasCorrelations =
        _correlations.containsKey(eventId) ||
        _correlations.values.any((list) => list.contains(eventId));

    final icon = _getEventIcon(event);
    final color = _getEventColor(event.type);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedEvent = isSelected ? null : event;
          });
          // Show correlation details if event has correlations
          if (hasCorrelations && !isSelected) {
            _showCorrelationDetails(event);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                : colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Time
              SizedBox(
                width: 50,
                child: Text(
                  time,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Icon & type bar
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              // Event info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (event.tags.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        children: event.tags.take(3).map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tag,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(fontSize: 10),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              // Correlation indicator
              if (hasCorrelations)
                Icon(Icons.link, color: Colors.red, size: 20),
              // Arrow if selected
              if (isSelected)
                Icon(Icons.chevron_right, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  Color _getEventColor(EventType type) {
    switch (type) {
      case EventType.meal:
        return Colors.green;
      case EventType.symptom:
        return Colors.red;
      case EventType.stool:
        return Colors.blue;
      case EventType.daily_checkup:
        return Colors.purple;
      case EventType.context_log:
        return Colors.cyan;
      default:
        return Colors.grey;
    }
  }

  /// Centralized icon selection based on event type
  IconData _getEventIcon(EventModel event) {
    // Weather auto events (context_log)
    if (event.type == EventType.context_log ||
        event.title.toLowerCase().contains('relevé météo auto')) {
      return Icons.cloud_done;
    }

    // Check for daily_checkup/weather events
    if (event.type == EventType.daily_checkup ||
        event.title.toLowerCase().contains('météo') ||
        event.title.toLowerCase().contains('meteo')) {
      return Icons.wb_cloudy;
    }

    // Check for stress/sleep in title or metadata
    final title = event.title.toLowerCase();
    if (title.contains('stress')) {
      return Icons.psychology;
    }
    if (title.contains('sommeil')) {
      return Icons.nightlight_round;
    }

    // Default icons based on event type
    switch (event.type) {
      case EventType.meal:
        return event.isSnack ? Icons.cookie : Icons.restaurant_menu;
      case EventType.symptom:
        return Icons.warning_amber;
      case EventType.stool:
        return Icons.water_drop;
      case EventType.daily_checkup:
        return Icons.wb_cloudy;
      default:
        return Icons.event;
    }
  }

  /// Shows detailed correlation information in a bottom sheet
  void _showCorrelationDetails(EventModel event) {
    final eventId = event.id?.toString() ?? '';

    // Find all related events
    final List<EventModel> relatedEvents = [];

    if (event.type == EventType.symptom && _correlations.containsKey(eventId)) {
      // This symptom is correlated with meals
      final mealIds = _correlations[eventId]!;
      relatedEvents.addAll(
        _events.where((e) => mealIds.contains(e.id?.toString())),
      );
    } else if (event.type == EventType.meal) {
      // Find symptoms correlated with this meal
      _correlations.forEach((symptomId, mealIds) {
        if (mealIds.contains(eventId)) {
          final symptom = _events.firstWhere(
            (e) => e.id?.toString() == symptomId,
            orElse: () => event, // fallback
          );
          if (symptom.id != event.id) {
            relatedEvents.add(symptom);
          }
        }
      });
    }

    if (relatedEvents.isEmpty) return;

    final eventTime = DateTime.parse(event.dateTime);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.link, color: Colors.red, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Corrélations détectées',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Fenêtre d\'analyse: 4-8h après repas',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Current event
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Événement sélectionné',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildCorrelationEventCard(event, colorScheme, null),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Related events
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      event.type == EventType.symptom
                          ? 'Repas possiblement responsables:'
                          : 'Symptômes survenus 4-8h après:',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...relatedEvents.map((related) {
                      final relatedTime = DateTime.parse(related.dateTime);
                      final timeDiff = event.type == EventType.symptom
                          ? eventTime.difference(relatedTime)
                          : relatedTime.difference(eventTime);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildCorrelationEventCard(
                          related,
                          colorScheme,
                          timeDiff,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Builds a card showing event details in correlation panel
  Widget _buildCorrelationEventCard(
    EventModel event,
    ColorScheme colorScheme,
    Duration? timeDiff,
  ) {
    final time = DateFormat(
      'EEE d MMM, HH:mm',
      'fr_FR',
    ).format(DateTime.parse(event.dateTime));
    final icon = _getEventIcon(event);
    final color = _getEventColor(event.type);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      time,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (timeDiff != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.red),
                      const SizedBox(width: 4),
                      Text(
                        '+${timeDiff.inHours}h${timeDiff.inMinutes % 60}',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (event.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: event.tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(tag, style: TextStyle(fontSize: 11)),
                );
              }).toList(),
            ),
          ],
          if (event.severity > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Sévérité:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                ...List.generate(
                  event.severity.clamp(0, 10),
                  (index) => Icon(Icons.circle, size: 8, color: Colors.red),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
