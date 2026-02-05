import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'themes/app_gradients.dart';
import 'event_model.dart';
import 'symptom_taxonomy.dart';
import 'utils/validators.dart';

class SymptomEntryDialog extends StatefulWidget {
  final EventModel? existingEvent;

  const SymptomEntryDialog({super.key, this.existingEvent});

  @override
  State<SymptomEntryDialog> createState() => _SymptomEntryDialogState();
}

class _SymptomEntryDialogState extends State<SymptomEntryDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PageController _pageController;
  int _currentStep = 0; // 0: Selection, 1: Intensities, 2: Summary

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
    _pageController = PageController();

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
    _pageController.dispose();
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
                  decoration: BoxDecoration(color: AppColors.painStart),
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
                              color: colorScheme.surface.withValues(
                                alpha: 0.25,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: colorScheme.surface.withValues(
                                  alpha: 0.4,
                                ),
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
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.3,
                                    ),
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
                                      DateFormat(
                                        'EEE d MMM',
                                        'fr_FR',
                                      ).format(_selectedDate),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
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
                                  initialTime: TimeOfDay.fromDateTime(
                                    _selectedDate,
                                  ),
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
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
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

                // Step indicator
                _buildStepIndicator(colorScheme),

                // Content (PageView with 3 steps)
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) =>
                        setState(() => _currentStep = index),
                    children: [
                      _buildStep1Selection(),
                      _buildStep2Intensities(),
                      _buildStep3Summary(),
                    ],
                  ),
                ),

                // Navigation buttons
                _buildNavigationButtons(theme, colorScheme),
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
          child: Stack(
            children: [
              // Background image silhouette
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 40,
                    right: 40,
                    top: 0,
                    bottom: 40,
                  ),
                  child: Transform.scale(
                    scale: 2.0,
                    child: ColorFiltered(
                      colorFilter: brightness == Brightness.dark
                          ? const ColorFilter.matrix([
                              -1, 0, 0, 0, 255, // Invert red
                              0, -1, 0, 0, 255, // Invert green
                              0, 0, -1, 0, 255, // Invert blue
                              0, 0, 0, 0.3, 0, // Alpha 30%
                            ])
                          : ColorFilter.mode(
                              colorScheme.outline.withValues(alpha: 0.3),
                              BlendMode.modulate,
                            ),
                      child: Image.asset(
                        'assets/abdomen.png',
                        fit: BoxFit.contain,
                        alignment: const Alignment(0, 0.3),
                      ),
                    ),
                  ),
                ),
              ),
              // Clickable grid zones (simple squares)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 60, vertical: 10),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                    childAspectRatio: 0.95,
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
                          color: isSelected
                              ? AppColors.painStart.withValues(alpha: 0.6)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.painStart
                                : colorScheme.outline.withValues(alpha: 0.3),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _getSimplifiedAbdomenLabel(zone),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : colorScheme.onSurface,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Returns simplified labels for abdomen zones
  String _getSimplifiedAbdomenLabel(String medicalName) {
    const Map<String, String> labels = {
      "Hypochondre D.": "Haut droit",
      "Épigastre": "Centre haut",
      "Hypochondre G.": "Haut gauche",
      "Flanc Droit": "Côté droit",
      "Ombilic": "Nombril",
      "Flanc Gauche": "Côté gauche",
      "Fosse Iliaque D.": "Bas droit",
      "Hypogastre": "Centre bas",
      "Fosse Iliaque G.": "Bas gauche",
    };
    return labels[medicalName] ?? medicalName;
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
          Divider(
            height: 1,
            color: colorScheme.onSurface.withValues(alpha: 0.06),
          ),
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
        Divider(
          height: 1,
          color: colorScheme.onSurface.withValues(alpha: 0.06),
        ),
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
                      color: isSelected
                          ? colorScheme.error
                          : colorScheme.onSurface,
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

  /// Step indicator (1/3, 2/3, 3/3)
  Widget _buildStepIndicator(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          final isActive = index <= _currentStep;
          final isCurrent = index == _currentStep;

          return Row(
            children: [
              Container(
                width: isCurrent ? 32 : 24,
                height: isCurrent ? 32 : 24,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.painStart : colorScheme.outline,
                  shape: BoxShape.circle,
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: AppColors.painStart.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isCurrent ? 14 : 12,
                  ),
                ),
              ),
              if (index < 2)
                Container(
                  width: 40,
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: isActive ? AppColors.painStart : colorScheme.outline,
                ),
            ],
          );
        }),
      ),
    );
  }

  /// Step 1: Selection (Tabs Abdomen/Details)
  Widget _buildStep1Selection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // Tab bar
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
                bottom: BorderSide(color: colorScheme.error, width: 3),
              ),
            ),
            labelStyle: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(icon: Icon(Icons.grid_view, size: 20), text: "Abdomen"),
              Tab(icon: Icon(Icons.list, size: 20), text: "Détails"),
            ],
          ),
        ),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildAbdomenTab(), _buildGeneralTab()],
          ),
        ),
      ],
    );
  }

  /// Step 2: Intensities (grouped sliders)
  Widget _buildStep2Intensities() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Group symptoms by L1 category
    final Map<String, List<String>> grouped = {};

    for (final zone in selectedAbdomenZones) {
      grouped.putIfAbsent('Abdomen', () => []);
      grouped['Abdomen']!.add(zone);
    }

    for (final fullPath in selectedGeneralZones) {
      final l1 = fullPath.split(' > ').first;
      grouped.putIfAbsent(l1, () => []);
      grouped[l1]!.add(fullPath);
    }

    if (grouped.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber, size: 64, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'Aucun symptôme sélectionné',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Retournez à l\'étape précédente pour sélectionner des zones',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: grouped.entries.map((entry) {
        final groupName = entry.key;
        final symptoms = entry.value;

        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                groupName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              ...symptoms.map((s) {
                final label = s.contains(' > ') ? s.split(' > ').last : s;
                return Padding(
                  padding: const EdgeInsets.only(left: 12, top: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 6,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: colorScheme.error,
                        inactiveTrackColor: colorScheme.outline,
                        thumbColor: colorScheme.error,
                        overlayColor: colorScheme.error.withValues(alpha: 0.2),
                        trackHeight: 6,
                      ),
                      child: Slider(
                        value: _zoneSeverities[groupName] ?? 5.0,
                        min: 0,
                        max: 10,
                        divisions: 10,
                        label: (_zoneSeverities[groupName] ?? 5.0)
                            .round()
                            .toString(),
                        onChanged: (v) =>
                            setState(() => _zoneSeverities[groupName] = v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 50,
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${(_zoneSeverities[groupName] ?? 5.0).toInt()}/10",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Step 3: Summary
  Widget _buildStep3Summary() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Récapitulatif',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...selectedAbdomenZones.map((zone) {
          final severity = (_zoneSeverities['Abdomen'] ?? 5.0).toInt();
          return _buildSummaryCard(zone, severity, colorScheme, theme);
        }),
        ...selectedGeneralZones.map((fullPath) {
          final l1 = fullPath.split(' > ').first;
          final severity = (_zoneSeverities[l1] ?? 5.0).toInt();
          return _buildSummaryCard(fullPath, severity, colorScheme, theme);
        }),
      ],
    );
  }

  Widget _buildSummaryCard(
    String label,
    int severity,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$severity/10',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Navigation buttons
  Widget _buildNavigationButtons(ThemeData theme, ColorScheme colorScheme) {
    return Container(
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous/Cancel button
          TextButton(
            onPressed: _currentStep == 0
                ? () => Navigator.pop(context)
                : () {
                    setState(() => _currentStep--);
                    _pageController.animateToPage(
                      _currentStep,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.error,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              _currentStep == 0 ? "Annuler" : "Précédent",
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Next/Validate button
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
                  if (_currentStep < 2) {
                    setState(() => _currentStep++);
                    _pageController.animateToPage(
                      _currentStep,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  } else {
                    // Validate and return
                    _validateAndReturn();
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  child: Text(
                    _currentStep == 2 ? "Valider" : "Suivant",
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
    );
  }

  void _validateAndReturn() {
    // 1. Validate selection (at least one zone selected)
    if (selectedAbdomenZones.isEmpty && selectedGeneralZones.isEmpty) {
      EventValidators.showValidationError(
        context,
        '❌ Sélectionnez au moins une zone ou un symptôme',
      );
      return;
    }

    // 2. Validate date
    final dateError = EventValidators.validateEventDate(_selectedDate);
    if (dateError != null) {
      EventValidators.showValidationError(context, dateError);
      return;
    }

    // 3. Validate all severities (1-10 range)
    for (var entry in _zoneSeverities.entries) {
      final severity = entry.value.toInt();
      final severityError = EventValidators.validateSeverity(severity);
      if (severityError != null) {
        EventValidators.showValidationError(
          context,
          'Sévérité "${entry.key}": $severityError',
        );
        return;
      }
    }

    List<Map<String, dynamic>> results = [];

    for (var zone in selectedAbdomenZones) {
      final zoneSeverity = (_zoneSeverities['Abdomen'] ?? 5.0).toInt();
      final mlTag = SymptomTaxonomy.inferMLTag(zone, 'Abdomen');
      final tags = mlTag != null ? [mlTag] : <String>[];

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
      final title = parts.last;
      final l1 = parts.first;
      final zoneSeverity = (_zoneSeverities[l1] ?? 5.0).toInt();
      final category = parts.length > 1 ? parts[1] : title;
      final mlTag = SymptomTaxonomy.inferMLTag(title, category);
      final tags = mlTag != null ? [mlTag] : parts.sublist(1);

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
  }
}
