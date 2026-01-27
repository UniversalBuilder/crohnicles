import '../event_model.dart';

class TimelineEventGroup {
  final DateTime bucketTime;
  final List<EventModel> meals;
  final List<EventModel> symptoms;
  final List<EventModel> stools;

  TimelineEventGroup({
    required this.bucketTime,
    required this.meals,
    required this.symptoms,
    required this.stools,
  });

  bool get hasAnyEvent => meals.isNotEmpty || symptoms.isNotEmpty || stools.isNotEmpty;
  
  int get maxSeverity {
    if (symptoms.isEmpty) return 0;
    return symptoms.map((e) => e.severity).reduce((a, b) => a > b ? a : b);
  }
}
