import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/log_service.dart';
import 'package:google_fonts/google_fonts.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final LogService _logService = LogService();
  List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _refreshLogs();
  }

  void _refreshLogs() {
    setState(() {
      _logs = _logService.logs.reversed.toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs Système'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              final text = _logs.join('\n');
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logs copiés dans le presse-papier')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshLogs,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              _logService.clear();
              _refreshLogs();
            },
          ),
        ],
      ),
      body: Container(
        color: Colors.black,
        child: ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: _logs.length,
          itemBuilder: (context, index) {
            final log = _logs[index];
            Color color = Colors.greenAccent;
            if (log.contains('Error') || log.contains('Exception') || log.contains('❌')) {
              color = Colors.redAccent;
            } else if (log.contains('Warning') || log.contains('⚠️')) {
              color = Colors.orangeAccent;
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Text(
                log,
                style: GoogleFonts.firaCode(
                  color: color,
                  fontSize: 12,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
