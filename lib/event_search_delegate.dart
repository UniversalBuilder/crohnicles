import 'package:flutter/material.dart';
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
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final results = snapshot.data!;
        if (results.isEmpty) return const Center(child: Text("Aucun résultat trouvé."));

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final event = results[index];
            return ListTile(
              title: Text(event.title),
              subtitle: Text("${event.time} - ${event.subtitle}"),
              leading: _getIconForType(event.type),
              onTap: () {
                // Optionnel: Naviguer vers le détail ou fermer
                // close(context, event);
              },
            );
          },
        );
      },
    );
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
      return titleMatch || tagMatch || subMatch;
    }).toList();
  }

  Icon _getIconForType(EventType type) {
    switch (type) {
        case EventType.meal: return const Icon(Icons.restaurant, color: Colors.orange);
        case EventType.symptom: return const Icon(Icons.bolt, color: Colors.red);
        case EventType.stool: return const Icon(Icons.waves, color: Colors.brown);
        case EventType.daily_checkup: return const Icon(Icons.bedtime, color: Colors.indigo);
    }
  }
}
