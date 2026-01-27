import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'event_model.dart';

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

  @override
  void initState() {
    super.initState();

    // Pre-fill data if editing existing event
    if (widget.existingEvent != null) {
      final event = widget.existingEvent!;
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
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.95),
                AppColors.surfaceGlass.withValues(alpha: 0.90),
              ],
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 40,
                offset: const Offset(0, 20),
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
                  decoration: const BoxDecoration(
                    gradient: AppColors.stoolGradient,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.waves,
                          size: 28,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          "Nouvelle Selle",
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ],
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
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: AppColors.stoolGradient.scale(0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.stoolStart.withValues(
                                alpha: 0.2,
                              ),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            "Type $_selectedType : ${_bristolDescriptions[_selectedType]}",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.stoolEnd,
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
                                        ? AppColors.stoolGradient
                                        : null,
                                    color: isSelected
                                        ? null
                                        : Colors.grey.shade100,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.transparent
                                          : AppColors.stoolStart.withValues(
                                              alpha: 0.3,
                                            ),
                                      width: 2,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: AppColors.stoolStart
                                                  .withValues(alpha: 0.4),
                                              blurRadius: 16,
                                              offset: const Offset(0, 6),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    "$type",
                                    style: GoogleFonts.inter(
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.stoolEnd,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
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
                            color: Colors.white.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey.shade200,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              SwitchListTile(
                                title: Text(
                                  "Urgence impérieuse",
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                value: _isUrgent,
                                onChanged: (val) =>
                                    setState(() => _isUrgent = val),
                                secondary: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: _isUrgent
                                        ? LinearGradient(
                                            colors: [
                                              Colors.orange.shade400,
                                              Colors.orange.shade600,
                                            ],
                                          )
                                        : null,
                                    color: _isUrgent
                                        ? null
                                        : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.warning_amber_rounded,
                                    color: _isUrgent
                                        ? Colors.white
                                        : Colors.orange,
                                    size: 20,
                                  ),
                                ),
                                activeColor: AppColors.stoolEnd,
                              ),
                              Divider(height: 1, color: Colors.grey.shade200),
                              SwitchListTile(
                                title: Text(
                                  "Présence de sang",
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                value: _hasBlood,
                                onChanged: (val) =>
                                    setState(() => _hasBlood = val),
                                secondary: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: _hasBlood
                                        ? AppColors.painGradient
                                        : null,
                                    color: _hasBlood
                                        ? null
                                        : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.water_drop,
                                    color: _hasBlood
                                        ? Colors.white
                                        : Colors.red,
                                    size: 20,
                                  ),
                                ),
                                activeColor: AppColors.painEnd,
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
                        color: Colors.black.withValues(alpha: 0.06),
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
                          foregroundColor: AppColors.stoolStart,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          "Annuler",
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.stoolGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.stoolStart.withValues(
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
                              Navigator.pop(context, {
                                'type': _selectedType,
                                'isUrgent': _isUrgent,
                                'hasBlood': _hasBlood,
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
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
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
