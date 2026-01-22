import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'event_model.dart';
import 'database_helper.dart';
import 'app_theme.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<EventModel>> _events = {};
  List<EventModel> _selectedEvents = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final dbHelper = DatabaseHelper();
    final eventsData = await dbHelper.getEvents();
    final allEvents = eventsData.map((e) => EventModel.fromMap(e)).toList();

    Map<DateTime, List<EventModel>> groupedEvents = {};

    for (var event in allEvents) {
      try {
        final date = DateTime.parse(event.dateTime);
        final day = DateTime(date.year, date.month, date.day); // Normalise date (no time)
        
        if (groupedEvents[day] == null) groupedEvents[day] = [];
        groupedEvents[day]!.add(event);
      } catch (e) {
        // Skip invalid dates
      }
    }

    setState(() {
      _events = groupedEvents;
      _selectedEvents = _getEventsForDay(_selectedDay!);
    });
  }

  List<EventModel> _getEventsForDay(DateTime day) {
    // Normalize date to match keys
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
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
          "Calendrier",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Column(
        children: [
          TableCalendar<EventModel>(
            firstDay: DateTime.utc(2023, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: CalendarFormat.month,
            startingDayOfWeek: StartingDayOfWeek.monday,
            eventLoader: _getEventsForDay,
            onDaySelected: (selectedDay, focusedDay) {
              if (!isSameDay(_selectedDay, selectedDay)) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                  _selectedEvents = _getEventsForDay(selectedDay);
                });
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            calendarStyle: const CalendarStyle(
              markersMaxCount: 4,
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return null;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: events.take(4).map((event) {
                    Gradient dotGradient;
                    if (event.type == EventType.symptom) {
                      dotGradient = AppColors.painGradient;
                    } else if (event.type == EventType.meal) {
                      dotGradient = AppColors.mealGradient;
                    } else if (event.type == EventType.stool) {
                      dotGradient = AppColors.stoolGradient;
                    } else {
                      dotGradient = AppColors.checkupGradient;
                    }
                    
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: dotGradient,
                        boxShadow: [
                          BoxShadow(
                            color: (event.type == EventType.symptom
                                    ? AppColors.painStart
                                    : event.type == EventType.meal
                                        ? AppColors.mealStart
                                        : event.type == EventType.stool
                                            ? AppColors.stoolStart
                                            : AppColors.primaryStart)
                                .withValues(alpha: 0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: ListView.builder(
              itemCount: _selectedEvents.length,
              itemBuilder: (context, index) {
                final event = _selectedEvents[index];
                return _buildEventTile(event);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventTile(EventModel event) {
    IconData icon;
    Gradient gradient;

    switch (event.type) {
      case EventType.meal:
        icon = event.isSnack ? Icons.cookie_outlined : Icons.restaurant;
        gradient = AppColors.mealGradient;
        break;
      case EventType.symptom:
        icon = Icons.bolt;
        gradient = AppColors.painGradient;
        break;
      case EventType.stool:
        icon = Icons.waves;
        gradient = AppColors.stoolGradient;
        break;
      case EventType.daily_checkup:
        icon = Icons.bedtime;
        gradient = AppColors.checkupGradient;
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.white.withValues(alpha: 0.95),
            AppColors.surfaceGlass.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (event.type == EventType.symptom
                  ? AppColors.painStart
                  : event.type == EventType.meal
                      ? AppColors.mealStart
                      : event.type == EventType.stool
                          ? AppColors.stoolStart
                          : AppColors.primaryStart)
              .withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (event.type == EventType.symptom
                    ? AppColors.painStart
                    : event.type == EventType.meal
                        ? AppColors.mealStart
                        : event.type == EventType.stool
                            ? AppColors.stoolStart
                            : AppColors.primaryStart)
                .withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: (event.type == EventType.symptom
                        ? AppColors.painStart
                        : event.type == EventType.meal
                            ? AppColors.mealStart
                            : event.type == EventType.stool
                                ? AppColors.stoolStart
                                : AppColors.primaryStart)
                    .withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        title: Text(
          event.title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          event.time,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        trailing: event.severity > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: gradient.scale(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${event.severity}/10",
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
