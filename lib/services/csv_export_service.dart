import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database_helper.dart';
import '../event_model.dart';

/// Service d'export CSV pour conformité RGPD
/// Exporte toutes les données utilisateur dans un format portable
class CsvExportService {
  static const String _fileName = 'crohnicles_export';
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  static final DateFormat _fileNameFormat = DateFormat('yyyyMMdd_HHmmss');

  /// Exporte toutes les données en CSV et retourne le chemin du fichier
  /// 
  /// Format CSV :
  /// - Date,Type,Titre,Sévérité,Tags,Métadonnées
  /// - Encodage UTF-8 avec BOM pour Excel
  /// - Séparateur virgule, guillemets pour échappement
  Future<String> exportAllDataToCsv() async {
    final db = DatabaseHelper();
    
    // Récupérer tous les événements
    final eventsMap = await db.getEvents();
    final events = eventsMap.map((e) => EventModel.fromMap(e)).toList();
    
    // Générer CSV
    final csvContent = _generateCsvContent(events);
    
    // Sauvegarder fichier
    final filePath = await _saveCsvFile(csvContent);
    
    return filePath;
  }

  /// Génère le contenu CSV avec header et toutes les lignes
  String _generateCsvContent(List<EventModel> events) {
    final buffer = StringBuffer();
    
    // UTF-8 BOM pour Excel (permet d'ouvrir correctement les accents)
    buffer.write('\uFEFF');
    
    // Header
    buffer.writeln('Date,Type,Titre,Sévérité,Tags,Métadonnées');
    
    // Données
    for (final event in events) {
      buffer.writeln(_eventToCsvRow(event));
    }
    
    return buffer.toString();
  }

  /// Convertit un événement en ligne CSV
  String _eventToCsvRow(EventModel event) {
    final date = _dateFormat.format(event.timestamp);
    final type = _eventTypeToString(event.type);
    final title = _escapeCsv(event.title);
    final severity = event.severity.toString();
    final tags = _escapeCsv(event.tags.join(';')); // Tags séparés par ;
    final metadataMap = event.metaData != null && event.metaData!.isNotEmpty
        ? jsonDecode(event.metaData!) as Map<String, dynamic>?
        : null;
    final metadata = _escapeCsv(_formatMetadata(metadataMap));
    
    return '$date,$type,$title,$severity,$tags,$metadata';
  }

  /// Convertit le type d'événement en string lisible
  String _eventTypeToString(EventType type) {
    switch (type) {
      case EventType.meal:
        return 'Repas';
      case EventType.symptom:
        return 'Symptôme';
      case EventType.stool:
        return 'Selles';
      case EventType.daily_checkup:
        return 'Bilan';
      case EventType.context_log:
        return 'Contexte';
    }
  }

  /// Formate les métadonnées JSON en string lisible
  String _formatMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null || metadata.isEmpty) return '';
    
    final parts = <String>[];
    
    // Aliments (pour repas)
    if (metadata.containsKey('foods')) {
      final foods = metadata['foods'] as List?;
      if (foods != null && foods.isNotEmpty) {
        final foodNames = foods
            .map((f) => f is Map ? f['name'] : f.toString())
            .join('; ');
        parts.add('Aliments: $foodNames');
      }
    }
    
    // Zone (pour symptômes)
    if (metadata.containsKey('zone') && metadata['zone'] != null) {
      parts.add('Zone: ${metadata['zone']}');
    }
    
    // Échelle Bristol (pour selles)
    if (metadata.containsKey('bristol_scale')) {
      parts.add('Bristol: ${metadata['bristol_scale']}');
    }
    
    // Urgence (pour selles)
    if (metadata.containsKey('urgency')) {
      parts.add('Urgence: ${metadata['urgency']}');
    }
    
    // Météo
    if (metadata.containsKey('weather')) {
      final weather = metadata['weather'] as Map?;
      if (weather != null) {
        final temp = weather['temperature'];
        final condition = weather['condition'];
        if (temp != null) parts.add('Température: ${temp}°C');
        if (condition != null) parts.add('Météo: $condition');
      }
    }
    
    return parts.join(' | ');
  }

  /// Échappe les caractères spéciaux CSV (guillemets, virgules, retours ligne)
  String _escapeCsv(String value) {
    if (value.isEmpty) return '';
    
    // Si contient guillemets, virgules ou retours ligne, encadrer de guillemets
    if (value.contains('"') || value.contains(',') || value.contains('\n')) {
      // Doubler les guillemets internes
      final escaped = value.replaceAll('"', '""');
      return '"$escaped"';
    }
    
    return value;
  }

  /// Sauvegarde le CSV dans le répertoire Documents et retourne le chemin
  Future<String> _saveCsvFile(String content) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = _fileNameFormat.format(DateTime.now());
    final fileName = '${_fileName}_$timestamp.csv';
    final filePath = '${directory.path}/$fileName';
    
    final file = File(filePath);
    await file.writeAsString(content, encoding: utf8);
    
    return filePath;
  }

  /// Exporte et partage le fichier CSV via le système de partage
  /// 
  /// Sur mobile : ouvre la sheet de partage (email, cloud, etc.)
  /// Sur desktop : copie le fichier dans Documents
  Future<void> exportAndShare() async {
    try {
      final filePath = await exportAllDataToCsv();
      
      // Partager via le système (mobile) ou notifier le chemin (desktop)
      if (Platform.isAndroid || Platform.isIOS) {
        await Share.shareXFiles(
          [XFile(filePath)],
          subject: 'Export Crohnicles - ${_fileNameFormat.format(DateTime.now())}',
          text: 'Mes données Crohnicles au format CSV',
        );
      } else {
        // Desktop : fichier sauvegardé dans Documents
        print('[CSV Export] Fichier sauvegardé: $filePath');
      }
    } catch (e) {
      print('[CSV Export] Erreur: $e');
      rethrow;
    }
  }

  /// Retourne le nombre total d'événements à exporter
  Future<int> getEventCount() async {
    final db = DatabaseHelper();
    final events = await db.getEvents();
    return events.length;
  }

  /// Retourne la taille estimée du fichier CSV en Ko
  Future<int> getEstimatedSizeKb() async {
    final db = DatabaseHelper();
    final events = await db.getEvents();
    
    // Estimation : ~150 bytes par ligne + header
    final estimatedBytes = (events.length * 150) + 100;
    return (estimatedBytes / 1024).ceil();
  }
}
