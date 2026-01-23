import 'package:flutter_test/flutter_test.dart';
import 'package:crohnicles/event_model.dart';
import 'dart:convert';

void main() {
  group('EventModel', () {
    test('toMap converts meal event with metadata', () {
      final event = EventModel(
        id: 1,
        type: EventType.meal,
        dateTime: '2026-01-23T12:30:00',
        title: 'Déjeuner',
        subtitle: 'Pâtes, Poulet',
        tags: ['Féculent', 'Protéine'],
        severity: 0,
        metaData: jsonEncode([
          {'name': 'Pâtes', 'category': 'Féculent'},
          {'name': 'Poulet', 'category': 'Protéine'},
        ]),
      );

      final map = event.toMap();

      expect(map['type'], 'meal');
      expect(map['title'], 'Déjeuner');
      expect(map['tags'], 'Féculent,Protéine');
      expect(map['meta_data'], contains('Pâtes'));
    });

    test('fromMap reconstructs event with ISO8601 timestamp', () {
      final map = {
        'id': 2,
        'type': 'symptom',
        'dateTime': '2026-01-23T14:30:00',
        'title': 'Douleur Abdominale',
        'subtitle': 'Zone épigastrique',
        'tags': 'Abdomen,Épigastre',
        'severity': 7,
        'isUrgent': 0,
        'isSnack': 0,
        'meta_data': '{"zones":["Épigastre"]}',
      };

      final event = EventModel.fromMap(map);

      expect(event.type, EventType.symptom);
      expect(event.severity, 7);
      expect(DateTime.parse(event.dateTime).year, 2026);
      expect(event.tags, ['Abdomen', 'Épigastre']);
    });

    test('EventType enum converts to/from string', () {
      expect(EventType.meal.toString().split('.').last, 'meal');
      expect(EventType.symptom.toString().split('.').last, 'symptom');
      expect(EventType.stool.toString().split('.').last, 'stool');
    });

    test('Event with no tags stores empty list', () {
      final event = EventModel(
        id: 1,
        type: EventType.daily_checkup,
        dateTime: DateTime.now().toIso8601String(),
        title: 'Bilan du Soir',
        subtitle: 'Résumé quotidien',
        tags: [],
      );

      final map = event.toMap();
      final reconstructed = EventModel.fromMap(map);

      expect(reconstructed.tags, isEmpty);
    });
  });
}
