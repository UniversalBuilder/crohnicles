import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'event_model.dart';
import 'database_helper.dart';

class EventSearchDelegate extends SearchDelegate {
  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    if (query.isEmpty) {
      return const Center(child: Text("Recherchez un aliment, un symptôme..."));
    }

    return FutureBuilder<List<EventModel>>(
      future: _searchEvents(query),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final results = snapshot.data!;
        if (results.isEmpty) {
          return const Center(child: Text("Aucun résultat trouvé."));
        }

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final event = results[index];
            return _buildEventCard(event, context);
          },
        );
      },
    );
  }

  Widget _buildEventCard(EventModel event, BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateTime = DateTime.parse(event.dateTime);
    final formattedDate = DateFormat(
      'd MMM yyyy • HH:mm',
      'fr_FR',
    ).format(dateTime);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () {
          close(context, event);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _getIconForType(event.type),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          formattedDate,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (event.type == EventType.symptom)
                    _buildSeverityBadge(event.severity),
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
                        color: _getColorForType(
                          event.type,
                        ).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tag,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _getColorForType(event.type),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              if (event.type == EventType.meal && event.metaData != null) ...[
                const SizedBox(height: 8),
                _buildMealDetails(event.metaData!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMealDetails(String metaData) {
    try {
      final data = jsonDecode(metaData);
      final foods = data['foods'] as List?;
      if (foods == null || foods.isEmpty) return const SizedBox.shrink();

      return Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aliments:',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              ...foods.take(3).map((food) {
                return Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Row(
                    children: [
                      Icon(Icons.restaurant, size: 12, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        food['name'] ?? 'Inconnu',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (foods.length > 3)
                Padding(
                  padding: const EdgeInsets.only(left: 24, top: 2),
                  child: Text(
                    '+ ${foods.length - 3} autre(s)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          );
        },
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildSeverityBadge(int severity) {
    Color color;
    if (severity <= 3) {
      color = Colors.green;
    } else if (severity <= 6) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$severity/10',
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Icon _getIconForType(EventType type) {
    switch (type) {
      case EventType.meal:
        return const Icon(Icons.restaurant, color: Colors.orange);
      case EventType.symptom:
        return const Icon(Icons.bolt, color: Colors.red);
      case EventType.stool:
        return const Icon(Icons.waves, color: Colors.brown);
      case EventType.daily_checkup:
        return const Icon(Icons.bedtime, color: Colors.indigo);
    }
  }

  Color _getColorForType(EventType type) {
    switch (type) {
      case EventType.meal:
        return Colors.orange;
      case EventType.symptom:
        return Colors.red;
      case EventType.stool:
        return Colors.brown;
      case EventType.daily_checkup:
        return Colors.indigo;
    }
  }

  Future<List<EventModel>> _searchEvents(String query) async {
    final dbHelper = DatabaseHelper();
    final allEventsMap = await dbHelper.getEvents();
    final allEvents = allEventsMap.map((e) => EventModel.fromMap(e)).toList();

    return allEvents.where((e) {
      final q = query.toLowerCase();
      final titleMatch = e.title.toLowerCase().contains(q);
      final tagMatch = e.tags.any((t) => t.toLowerCase().contains(q));
      final subMatch = e.subtitle.toLowerCase().contains(q);

      // Search in meal foods
      if (e.type == EventType.meal && e.metaData != null) {
        try {
          final decoded = jsonDecode(e.metaData!);
          List<dynamic>? foods;

          if (decoded is List) {
            foods = decoded;
          } else if (decoded is Map && decoded.containsKey('foods')) {
            var f = decoded['foods'];
            if (f is String) {
              try {
                f = jsonDecode(f);
              } catch (_) {}
            }
            if (f is List) {
              foods = f;
            }
          }

          if (foods != null) {
            final foodMatch = foods.any((food) {
              final name = food['name'] as String?;
              return name != null && name.toLowerCase().contains(q);
            });
            if (foodMatch) return true;
          }
        } catch (_) {}
      }

      return titleMatch || tagMatch || subMatch;
    }).toList();
  }
}
