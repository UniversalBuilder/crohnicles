import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'event_model.dart';
import 'database_helper.dart';
import 'app_theme.dart';

class EventDetailPage extends StatefulWidget {
  final EventModel event;

  const EventDetailPage({Key? key, required this.event}) : super(key: key);

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  List<EventModel> _relatedEvents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRelatedEvents();
  }

  Future<void> _loadRelatedEvents() async {
    final db = DatabaseHelper();
    final eventTime = DateTime.parse(widget.event.dateTime);
    
    if (widget.event.type == EventType.meal) {
      // Find symptoms 2-24h after this meal
      final startTime = eventTime.add(const Duration(hours: 2));
      final endTime = eventTime.add(const Duration(hours: 24));
      
      final allEvents = await db.getEvents();
      _relatedEvents = allEvents
          .map((e) => EventModel.fromMap(e))
          .where((e) {
            if (e.type != EventType.symptom || e.severity < 6) return false;
            try {
              final eTime = DateTime.parse(e.dateTime);
              return eTime.isAfter(startTime) && eTime.isBefore(endTime);
            } catch (e) {
              return false;
            }
          })
          .toList();
    } else if (widget.event.type == EventType.symptom) {
      // Find meals 2-24h before this symptom
      final startTime = eventTime.subtract(const Duration(hours: 24));
      final endTime = eventTime.subtract(const Duration(hours: 2));
      
      final allEvents = await db.getEvents();
      _relatedEvents = allEvents
          .map((e) => EventModel.fromMap(e))
          .where((e) {
            if (e.type != EventType.meal) return false;
            try {
              final eTime = DateTime.parse(e.dateTime);
              return eTime.isAfter(startTime) && eTime.isBefore(endTime);
            } catch (e) {
              return false;
            }
          })
          .toList();
    }
    
    setState(() => _isLoading = false);
  }

  LinearGradient _getGradient() {
    switch (widget.event.type) {
      case EventType.meal:
        return AppColors.mealGradient;
      case EventType.symptom:
        return AppColors.painGradient;
      case EventType.stool:
        return AppColors.stoolGradient;
      default:
        return AppColors.primaryGradient;
    }
  }

  IconData _getIcon() {
    switch (widget.event.type) {
      case EventType.meal:
        return widget.event.isSnack ? Icons.local_cafe : Icons.restaurant;
      case EventType.symptom:
        return Icons.favorite_border;
      case EventType.stool:
        return Icons.analytics_outlined;
      default:
        return Icons.event_note;
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventTime = DateTime.parse(widget.event.dateTime);
    
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: _getGradient(),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            _getIcon(),
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.event.title,
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          DateFormat('EEEE d MMMM yyyy • HH:mm', 'fr_FR')
                              .format(eventTime),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMainDetails(),
                  const SizedBox(height: 24),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_relatedEvents.isNotEmpty)
                    _buildRelatedEvents(),
                  const SizedBox(height: 24),
                  _buildActions(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainDetails() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Détails',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            
            if (widget.event.subtitle.isNotEmpty) ...[
              _buildDetailRow(Icons.info_outline, 'Note', widget.event.subtitle),
              const SizedBox(height: 12),
            ],
            
            if (widget.event.tags.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.label_outline, size: 20, color: Colors.grey[600]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.event.tags.map((tag) {
                        return Chip(
                          label: Text(tag),
                          labelStyle: GoogleFonts.inter(fontSize: 12),
                          backgroundColor: _getGradient()
                              .colors
                              .first
                              .withValues(alpha: 0.15),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            
            if (widget.event.type == EventType.symptom && widget.event.severity > 0) ...[
              _buildDetailRow(
                Icons.speed,
                'Sévérité',
                '${widget.event.severity}/10',
              ),
              const SizedBox(height: 12),
            ],
            
            if (widget.event.type == EventType.meal && widget.event.metaData != null)
              _buildFoodsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodsList() {
    try {
      final foods = jsonDecode(widget.event.metaData!) as List<dynamic>;
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.restaurant_menu, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 12),
              Text(
                'Composition',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...foods.map((food) {
            final foodName = food['name'] ?? 'Aliment';
            final category = food['category'] ?? '';
            return Padding(
              padding: const EdgeInsets.only(left: 32, top: 4),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.mealStart,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      category.isNotEmpty ? '$foodName ($category)' : foodName,
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildRelatedEvents() {
    final title = widget.event.type == EventType.meal
        ? 'Symptômes dans les 24h suivantes'
        : 'Repas suspectés (24h avant)';
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.link,
                  color: _getGradient().colors.first,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._relatedEvents.map((event) {
              final eventTime = DateTime.parse(event.dateTime);
              final diffHours = eventTime
                  .difference(DateTime.parse(widget.event.dateTime))
                  .inHours
                  .abs();
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${diffHours}h ${widget.event.type == EventType.meal ? "après" : "avant"}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (event.type == EventType.symptom)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.painStart.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${event.severity}/10',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.painStart,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Modification à venir')),
              );
            },
            icon: const Icon(Icons.edit),
            label: const Text('Modifier'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Supprimer'),
                  content: const Text('Voulez-vous vraiment supprimer cet événement ?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Annuler'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Supprimer'),
                    ),
                  ],
                ),
              );
              
              if (confirm == true && widget.event.id != null) {
                await DatabaseHelper().deleteEvent(widget.event.id!);
                if (mounted) {
                  Navigator.pop(context, true); // Return true to refresh timeline
                }
              }
            },
            icon: const Icon(Icons.delete),
            label: const Text('Supprimer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
