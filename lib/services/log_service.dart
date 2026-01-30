import 'package:flutter/foundation.dart';

class LogService {
  static final LogService _instance = LogService._internal();
  
  factory LogService() {
    return _instance;
  }

  LogService._internal();

  final List<String> _logs = [];
  final int _maxLogs = 1000;

  List<String> get logs => List.unmodifiable(_logs);

  void log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] $message';
    
    if (kDebugMode) {
      print(logEntry);
    }
    
    _logs.add(logEntry);
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }
  }

  void clear() {
    _logs.clear();
  }
}
