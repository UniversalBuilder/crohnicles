import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'themes/app_gradients.dart';
import 'event_model.dart';
import 'symptom_taxonomy.dart';

class SymptomEntryDialog extends StatefulWidget {
  final EventModel? existingEvent;

  const SymptomEntryDialog({super.key, this.existingEvent});

  @override
  State<SymptomEntryDialog> createState() => _SymptomEntryDialogState();
}

class _SymptomEntryDialogState extends State<SymptomEntryDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Per-zone severity tracking
  final Map<String, double> _zoneSeverities = {};

  // Sélection multiple
  Set<String> selectedAbdomenZones = {};
  Set<String> selectedGeneralZones = {};

  // HIERARCHY NAVIGATION STATE
  String? currentLevel1; // e.g. "Articulations"
  String? currentLevel2; // e.g. "Membre Sup."

  // CONSTANT HIERARCHY
  static const Map<String, dynamic> symptomHierarchy = {
    'Articulations': {
      'Membre Sup.': ['Épaule', 'Coude', 'Poignet', 'Main/Doigts'],
      'Membre Inf.': ['Hanche', 'Genou', 'Cheville', 'Orteils'],
      'Axial': ['Cervicales', 'Lombaires', 'Bassin'],
    },
    'Bouche/ORL': {
      'Bouche': ['Gencives', 'Langue', 'Aphtes', 'Sécheresse'],
      'Yeux': ['Uvéite (Rougeur)', 'Sécheresse', 'Douleur'],
    },
    'Peau': {
      'Zones': ['Psoriasis', 'Érythème noueux', 'Eczéma'],
    },
    'Général': {
      'Systémique': ['Fatigue intense', 'Fièvre', 'Frissons', 'Perte appétit'],
    },
  };

  // Tab 1 Data : Abdomen Grid (3x3)
  final List<String> abdomenZones = [
    "Hypochondre D.",
    "Épigastre",
    "Hypochondre G.",
    "Flanc Droit",
    "Ombilic",
    "Flanc Gauche",
    "Fosse Iliaque D.",
    "Hypogastre",
    "Fosse Iliaque G.",
  ];

  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Pre-fill data if editing existing event
    if (widget.existingEvent != null) {
      final event = widget.existingEvent!;
      _selectedDate = event.timestamp;

      // Try to parse new JSON format
      if (event.metaData != null && event.metaData!.isNotEmpty) {
        try {
          final metadata = jsonDecode(event.metaData!);
          if (metadata['zones'] != null && metadata['zones'] is List) {
            final zones = metadata['zones'] as List;
            for (var zone in zones) {
              final name = zone['name'] as String?;
              final severity = (zone['severity'] as num?)?.toDouble() ?? 5.0;
              if (name != null) {
                // Check if it's an abdomen zone
                if (abdomenZones.contains(name)) {
                  selectedAbdomenZones.add(name);
                } else {
                  // Assume it's a general zone
                  selectedGeneralZones.add(name);
                }
                _zoneSeverities[name] = severity;
              }
            }
          }
        } catch (e) {
          print('[SYMPTOM EDIT] Failed to parse meta_data: $e');
          // Fallback: use title as single zone
          selectedAbdomenZones.add(event.title);
          _zoneSeverities[event.title] = event.severity.toDouble();
        }
      } else {
        // Old format: single zone from title
        if (abdomenZones.contains(event.title)) {
          selectedAbdomenZones.add(event.title);
        }
        _zoneSeverities[event.title] = event.severity.toDouble();
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- HIERARCHY HELPERS ---
  void _resetHierarchy() {
    setState(() {
      currentLevel1 = null;
      currentLevel2 = null;
    });
  }

  Icon _getIconForCategory(String category) {
    switch (category) {
      case 'Articulations':
        return const Icon(Icons.accessibility, color: Colors.orange);
      case 'Bouche/ORL':
        return const Icon(Icons.face, color: Colors.pink);
      case 'Peau':
        return const Icon(Icons.healing, color: Colors.brown);
      case 'Général':
        return const Icon(Icons.thermostat, color: Colors.red);
      default:
        return const Icon(Icons.help);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Gradient header
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.painStart,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.surface.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: colorScheme.surface.withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.bolt,
                              size: 28,
                              color: colorScheme.onPrimary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              "Nouveaux Symptômes",
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: colorScheme.onPrimary,
                                letterSpacing: -0.5,
                                shadows: [
                                  Shadow(
                                    color: colorScheme.onSurface.withValues(alpha: 0.3),
                                    offset: const Offset(0, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Date & Time Picker
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Date Picker
                          Container(
                            decoration: BoxDecoration(
                              color: colorScheme.surface.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                  locale: const Locale('fr', 'FR'),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: ColorScheme.light(
                                          primary: colorScheme.error,
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (date != null) {
                                  setState(() {
                                    _selectedDate = DateTime(
                                      date.year,
                                      date.month,
                                      date.day,
                                      _selectedDate.hour,
                                      _selectedDate.minute,
                                    );
                                  });
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      color: colorScheme.onPrimary,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat('EEE d MMM', 'fr_FR').format(_selectedDate),
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Time Picker
                          Container(
                            decoration: BoxDecoration(
                              color: colorScheme.surface.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              onTap: () async {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.fromDateTime(_selectedDate),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: ColorScheme.light(
                                          primary: colorScheme.error,
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (time != null) {
                                  setState(() {
                                    _selectedDate = DateTime(
                                      _selectedDate.year,
                                      _selectedDate.month,
                                      _selectedDate.day,
                                      time.hour,
                                      time.minute,
                                    );
                                  });
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      color: colorScheme.onPrimary,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat('HH:mm').format(_selectedDate),
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tab bar with gradient indicator
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.5),
                    border: Border(
                      bottom: BorderSide(
                        color: colorScheme.onSurface.withValues(alpha: 0.06),
                        width: 1,
                      ),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: colorScheme.error,
                    unselectedLabelColor: colorScheme.onSurfaceVariant,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: AppColors.painStart.withValues(alpha: 0.15),
                      border: Border(
                        bottom: BorderSide(
                          color: colorScheme.error,
                          width: 3,
                        ),
                      ),
                    ),
                    labelStyle: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.grid_view, size: 20),
                        text: "Abdomen",
                      ),
                      Tab(icon: Icon(Icons.list, size: 20), text: "Détails"),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [_buildAbdomenTab(), _buildGeneralTab()],
                        ),
                      ),

                      // Per-zone severity editor
                      if (selectedAbdomenZones.isNotEmpty ||
                          selectedGeneralZones.isNotEmpty)
                        Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            border: Border(
                              top: BorderSide(
                                color: colorScheme.outlineVariant,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Intensité par zone",
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Flexible(
                                child: ListView(
                                  shrinkWrap: true,
                                  children: [
                                    ...selectedAbdomenZones.map(
                                      (zone) => _buildZoneSeverityRow(zone),
                                    ),
                                    ...selectedGeneralZones.map((fullPath) {
                                      final parts = fullPath.split(' > ');
                                      return _buildZoneSeverityRow(parts[0]);
                                    }),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Actions
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: colorScheme.onSurface.withValues(alpha: 0.06),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: colorScheme.error,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          "Annuler",
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.painStart,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.error.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              List<Map<String, dynamic>> results = [];
                              for (var zone in selectedAbdomenZones) {
                                final zoneSeverity =
                                    (_zoneSeverities[zone] ?? 5.0).toInt();

                                // Infer ML tag for abdomen symptoms
                                final mlTag = SymptomTaxonomy.inferMLTag(
                                  zone,
                                  'Abdomen',
                                );
                                final tags = mlTag != null
                                    ? [mlTag]
                                    : <String>[];

                                results.add({
                                  'title': zone,
                                  'severity': zoneSeverity,
                                  'tags': tags,
                                  'meta_data': jsonEncode({
                                    'zones': [
                                      {'name': zone, 'severity': zoneSeverity},
                                    ],
                                  }),
                                });
                              }
                              for (var fullPath in selectedGeneralZones) {
                                final parts = fullPath.split(' > ');
                                final title = parts[0];
                                final zoneSeverity =
                                    (_zoneSeverities[title] ?? 5.0).toInt();

                                // Infer ML tag from category path
                                final category = parts.length > 1
                                    ? parts[1]
                                    : title;
                                final mlTag = SymptomTaxonomy.inferMLTag(
                                  title,
                                  category,
                                );
                                final tags = mlTag != null
                                    ? [mlTag]
                                    : parts.sublist(1);

                                results.add({
                                  'title': title,
                                  'severity': zoneSeverity,
                                  'tags': tags,
                                  'meta_data': jsonEncode({
                                    'zones': [
                                      {'name': title, 'severity': zoneSeverity},
                                    ],
                                  }),
                                  'timestamp': _selectedDate,
                                });
                              }
                              Navigator.pop(context, results);
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 14,
                              ),
                              child: Text(
                                "Valider",
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAbdomenTab() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "Sélectionnez les zones douloureuses :",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            itemCount: abdomenZones.length,
            itemBuilder: (context, index) {
              final zone = abdomenZones[index];
              final isSelected = selectedAbdomenZones.contains(zone);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      selectedAbdomenZones.remove(zone);
                    } else {
                      selectedAbdomenZones.add(zone);
                    }
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.painStart : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : colorScheme.outline,
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: colorScheme.error.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    zone,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGeneralTab() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    
    // Level 1: Categories
    if (currentLevel1 == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: symptomHierarchy.keys.map((key) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.painStart.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _getIconForCategory(key),
              ),
              title: Text(
                key,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: ShaderMask(
                shaderCallback: (bounds) =>
                    AppGradients.pain(brightness).createShader(bounds),
                child: Icon(Icons.chevron_right, color: colorScheme.surface),
              ),
              onTap: () => setState(() => currentLevel1 = key),
            ),
          );
        }).toList(),
      );
    }

    final l1Data = symptomHierarchy[currentLevel1!] as Map<String, dynamic>;

    // Level 2: Sub-categories
    if (currentLevel2 == null) {
      return Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: AppGradients.pain(brightness).scale(0.2),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ShaderMask(
                  shaderCallback: (bounds) =>
                      AppGradients.pain(brightness).createShader(bounds),
                  child: Icon(Icons.arrow_back, color: colorScheme.surface),
                ),
              ),
              title: Text(
                currentLevel1!,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onPrimary,
                ),
              ),
              subtitle: Text(
                "Sélectionnez les symptômes",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: _resetHierarchy,
            ),
          ),
          Divider(height: 1, color: colorScheme.onSurface.withValues(alpha: 0.06)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: l1Data.keys.map((key) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.outline, width: 1.5),
                  ),
                  child: ListTile(
                    title: Text(
                      key,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => setState(() => currentLevel2 = key),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      );
    }

    // Level 3: Leaf nodes (Selectable)
    final l3Data = l1Data[currentLevel2!] as List<String>;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.painStart.withValues(alpha: 0.2),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ShaderMask(
                shaderCallback: (bounds) =>
                    AppGradients.pain(brightness).createShader(bounds),
                child: Icon(Icons.arrow_back, color: colorScheme.surface),
              ),
            ),
            title: Text(
              "$currentLevel1 > $currentLevel2",
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onPrimary,
              ),
            ),
            subtitle: Text(
              "Sélectionnez les symptômes",
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimary.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
            onTap: () => setState(() => currentLevel2 = null),
          ),
        ),
        Divider(height: 1, color: colorScheme.onSurface.withValues(alpha: 0.06)),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: l3Data.map((item) {
              final fullPath = "$currentLevel1 > $currentLevel2 > $item";
              final isSelected = selectedGeneralZones.contains(fullPath);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.painStart.withValues(alpha: 0.3)
                      : colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.error.withValues(alpha: 0.5)
                        : colorScheme.outline,
                    width: 1.5,
                  ),
                ),
                child: CheckboxListTile(
                  title: Text(
                    item,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isSelected ? colorScheme.error : colorScheme.onSurface,
                    ),
                  ),
                  value: isSelected,
                  activeColor: colorScheme.error,
                  checkColor: colorScheme.onPrimary,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        selectedGeneralZones.add(fullPath);
                      } else {
                        selectedGeneralZones.remove(fullPath);
                      }
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildZoneSeverityRow(String zone) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final severity = _zoneSeverities[zone] ?? 5.0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              zone,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: colorScheme.error,
                inactiveTrackColor: colorScheme.outline,
                thumbColor: colorScheme.error,
                overlayColor: colorScheme.error.withValues(alpha: 0.2),
                trackHeight: 4,
              ),
              child: Slider(
                value: severity,
                min: 0,
                max: 10,
                divisions: 10,
                label: severity.round().toString(),
                onChanged: (v) => setState(() => _zoneSeverities[zone] = v),
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              "${severity.toInt()}/10",
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.error,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
