import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'themes/app_gradients.dart';
import 'event_model.dart';
import 'utils/validators.dart';

class StoolEntryDialog extends StatefulWidget {
  final EventModel? existingEvent;

  const StoolEntryDialog({super.key, this.existingEvent});

  @override
  State<StoolEntryDialog> createState() => _StoolEntryDialogState();
}

class _StoolEntryDialogState extends State<StoolEntryDialog> {
  int _selectedType = 4;
  bool _isUrgent = false;
  bool _hasBlood = false;

  final Map<int, String> _bristolDescriptions = {
    1: "Billes dures (difficile à évacuer)",
    2: "Saucisse grumeleuse",
    3: "Saucisse craquelée",
    4: "Saucisse ou serpent lisse (Idéal)",
    5: "Morceaux mous (facile à évacuer)",
    6: "Boueuse, morceaux déchiquetés",
    7: "Liquide (aucune partie solide)",
  };

  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();

    // Pre-fill data if editing existing event
    if (widget.existingEvent != null) {
      final event = widget.existingEvent!;
      _selectedDate = event.timestamp;
      // Extract type from title "Type X"
      final typeMatch = RegExp(r'Type (\d+)').firstMatch(event.title);
      if (typeMatch != null) {
        _selectedType = int.tryParse(typeMatch.group(1)!) ?? 4;
      }
      _isUrgent = event.isUrgent;
      _hasBlood = event.tags.any((tag) => tag.toLowerCase().contains('sang'));
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
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
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
                    color: AppColors.stoolStart,
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
                          Icons.waves,
                          size: 28,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          "Nouvelle Selle",
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: colorScheme.onPrimary,
                            letterSpacing: -0.5,
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
                                          primary: colorScheme.tertiary,
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
                  ]
                  ),
                ),

                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Bristol Scale Title
                        Text(
                          "Échelle de Bristol",
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.stoolStart.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colorScheme.tertiary.withValues(
                                alpha: 0.2,
                              ),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            "Type $_selectedType : ${_bristolDescriptions[_selectedType]}",
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.tertiary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Bristol Scale Circles (all visible, no scroll needed)
                        Center(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: List.generate(7, (index) {
                              final type = index + 1;
                              final isSelected = _selectedType == type;
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedType = type),
                                child: Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    gradient: isSelected
                                        ? AppGradients.stool(brightness)
                                        : null,
                                    color: isSelected
                                        ? null
                                        : colorScheme.surfaceContainerHighest,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.transparent
                                          : colorScheme.tertiary.withValues(
                                              alpha: 0.3,
                                            ),
                                      width: 2,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: colorScheme.tertiary.withValues(alpha: 0.4),
                                              blurRadius: 16,
                                              offset: const Offset(0, 6),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    "$type",
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: isSelected
                                          ? colorScheme.onPrimary
                                          : colorScheme.tertiary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Switches
                        Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surface.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colorScheme.outline,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              SwitchListTile(
                                title: Text(
                                  "Urgence impérieuse",
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                value: _isUrgent,
                                onChanged: (val) =>
                                    setState(() => _isUrgent = val),
                                secondary: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _isUrgent
                                        ? Colors.orange
                                        : colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.warning_amber_rounded,
                                    color: _isUrgent
                                        ? colorScheme.onPrimary
                                        : Colors.orange,
                                    size: 20,
                                  ),
                                ),
                                activeThumbColor: colorScheme.tertiary,
                              ),
                              Divider(height: 1, color: colorScheme.outline),
                              SwitchListTile(
                                title: Text(
                                  "Présence de sang",
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                value: _hasBlood,
                                onChanged: (val) =>
                                    setState(() => _hasBlood = val),
                                secondary: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _hasBlood
                                        ? colorScheme.error
                                        : colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.water_drop,
                                    color: _hasBlood
                                        ? colorScheme.onPrimary
                                        : colorScheme.error,
                                    size: 20,
                                  ),
                                ),
                                activeThumbColor: colorScheme.error,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
                          foregroundColor: colorScheme.tertiary,
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
                          color: AppColors.stoolStart,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.tertiary.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              // 1. Validate Bristol scale (1-7)
                              final bristolError = EventValidators.validateBristolScale(_selectedType);
                              if (bristolError != null) {
                                EventValidators.showValidationError(context, bristolError);
                                return;
                              }

                              // 2. Validate date
                              final dateError = EventValidators.validateEventDate(_selectedDate);
                              if (dateError != null) {
                                EventValidators.showValidationError(context, dateError);
                                return;
                              }

                              // All validations passed
                              Navigator.pop(context, {
                                'type': _selectedType,
                                'isUrgent': _isUrgent,
                                'hasBlood': _hasBlood,
                                'timestamp': _selectedDate,
                              });
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
}
