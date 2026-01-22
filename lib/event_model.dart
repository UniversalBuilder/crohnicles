enum EventType { meal, symptom, stool, daily_checkup }

class EventModel {
  final int? id;
  final EventType type;
  final String dateTime;
  final String title;
  final String subtitle; // Sert pour les détails ou les tags
  final List<String> tags;
  final int severity; // 0-10
  final bool isUrgent;
  final bool isSnack; // Nouvelle propriété pour distinguer Repas vs Encas
  final String? imagePath;
  final String? metaData;

  EventModel({
    this.id,
    required this.type,
    required this.dateTime, // Changed from time
    required this.title,
    required this.subtitle,
    this.tags = const [],
    this.severity = 0,
    this.isUrgent = false,
    this.isSnack = false,
    this.imagePath,
    this.metaData,
  });

  // Getter for display time
  String get time {
     try {
       final dt = DateTime.parse(dateTime);
       return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
     } catch (e) {
       return "";
     }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'dateTime': dateTime,
      'title': title,
      'subtitle': subtitle,
      'severity': severity,
      'tags': tags.join(','),
      'isUrgent': isUrgent ? 1 : 0,
      'isSnack': isSnack ? 1 : 0,
      'imagePath': imagePath,
      'meta_data': metaData,
    };
  }

  factory EventModel.fromMap(Map<String, dynamic> map) {
    return EventModel(
      id: map['id'],
      type: EventType.values.firstWhere((e) => e.name == map['type'], orElse: () => EventType.meal),
      dateTime: map['dateTime'] ?? DateTime.now().toIso8601String(),
      title: map['title'] ?? "Sans titre",
      subtitle: map['subtitle'] ?? "",
      severity: map['severity'] ?? 0,
      tags: (map['tags'] as String?)?.split(',').where((s) => s.isNotEmpty).toList() ?? [],
      isUrgent: map['isUrgent'] == 1,
      isSnack: map['isSnack'] == 1,
      imagePath: map['imagePath'],
      metaData: map['meta_data'],
    );
  }
}

