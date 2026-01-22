import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';

class SymptomEntryDialog extends StatefulWidget {
  const SymptomEntryDialog({super.key});

  @override
  State<SymptomEntryDialog> createState() => _SymptomEntryDialogState();
}

class _SymptomEntryDialogState extends State<SymptomEntryDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // State partagé
  double severity = 5.0;
  
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
        'Zones': ['Psoriasis', 'Érythème noueux', 'Eczéma']
    },
    'Général': {
        'Systémique': ['Fatigue intense', 'Fièvre', 'Frissons', 'Perte appétit']
    }
  };

  // Tab 1 Data : Abdomen Grid (3x3)
  final List<String> abdomenZones = [
    "Hypochondre D.", "Épigastre", "Hypochondre G.",
    "Flanc Droit", "Ombilic", "Flanc Gauche",
    "Fosse Iliaque D.", "Hypogastre", "Fosse Iliaque G."
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      switch(category) {
          case 'Articulations': return const Icon(Icons.accessibility, color: Colors.orange);
          case 'Bouche/ORL': return const Icon(Icons.face, color: Colors.pink);
          case 'Peau': return const Icon(Icons.healing, color: Colors.brown);
          case 'Général': return const Icon(Icons.thermostat, color: Colors.red);
          default: return const Icon(Icons.help);
      }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 600,
          maxHeight: 700,
        ),
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
                    gradient: AppColors.painGradient,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                          Icons.bolt,
                          size: 28,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          "Nouveaux Symptômes",
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
                
                // Tab bar with gradient indicator
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.black.withValues(alpha: 0.06),
                        width: 1,
                      ),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: AppColors.painStart,
                    unselectedLabelColor: Colors.grey.shade600,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: const BoxDecoration(
                      gradient: AppColors.painGradient,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    labelStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    tabs: const [
                      Tab(icon: Icon(Icons.grid_view, size: 20), text: "Abdomen"),
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
                          children: [
                            _buildAbdomenTab(),
                            _buildGeneralTab(),
                          ],
                        ),
                      ),
                      
                      // Severity slider
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
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Intensité Globale",
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.painGradient,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.painStart.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    "${severity.toInt()}/10",
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SliderTheme(
                              data: SliderThemeData(
                                activeTrackColor: AppColors.painStart,
                                inactiveTrackColor: Colors.grey.shade300,
                                thumbColor: AppColors.painEnd,
                                overlayColor: AppColors.painStart.withValues(alpha: 0.2),
                                trackHeight: 6,
                              ),
                              child: Slider(
                                value: severity,
                                min: 0,
                                max: 10,
                                divisions: 10,
                                label: severity.round().toString(),
                                onChanged: (v) => setState(() => severity = v),
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
                          foregroundColor: AppColors.painStart,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                          gradient: AppColors.painGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.painStart.withValues(alpha: 0.3),
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
                                results.add({
                                  'title': zone,
                                  'severity': severity.toInt(),
                                  'tags': <String>[]
                                });
                              }
                              for (var fullPath in selectedGeneralZones) {
                                final parts = fullPath.split(' > ');
                                final title = parts[0];
                                results.add({
                                  'title': title,
                                  'severity': severity.toInt(),
                                  'tags': parts.sublist(1)
                                });
                              }
                              Navigator.pop(context, results);
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
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

  Widget _buildAbdomenTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "Sélectionnez les zones douloureuses :",
            style: GoogleFonts.inter(
              color: Colors.grey.shade600,
              fontSize: 14,
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
                    gradient: isSelected ? AppColors.painGradient : null,
                    color: isSelected ? null : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : Colors.grey.shade300,
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.painStart.withValues(alpha: 0.3),
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
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.black87,
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
    // Level 1: Categories
    if (currentLevel1 == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: symptomHierarchy.keys.map((key) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.painStart.withValues(alpha: 0.1),
                  AppColors.painEnd.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.painStart.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppColors.painGradient.scale(0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _getIconForCategory(key),
              ),
              title: Text(
                key,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              trailing: ShaderMask(
                shaderCallback: (bounds) => AppColors.painGradient.createShader(bounds),
                child: const Icon(
                  Icons.chevron_right,
                  color: Colors.white,
                ),
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
              gradient: AppColors.painGradient.scale(0.2),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ShaderMask(
                  shaderCallback: (bounds) => AppColors.painGradient.createShader(bounds),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                  ),
                ),
              ),
              title: Text(
                currentLevel1!,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              subtitle: Text(
                "Sélectionnez les symptômes",
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: _resetHierarchy,
            ),
          ),
          Divider(height: 1, color: Colors.black.withValues(alpha: 0.06)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: l1Data.keys.map((key) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1.5,
                    ),
                  ),
                  child: ListTile(
                    title: Text(
                      key,
                      style: GoogleFonts.inter(
                        fontSize: 14,
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
            gradient: AppColors.painGradient.scale(0.2),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ShaderMask(
                shaderCallback: (bounds) => AppColors.painGradient.createShader(bounds),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                ),
              ),
            ),
            title: Text(
              "$currentLevel1 > $currentLevel2",
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            subtitle: Text(
              "Sélectionnez les symptômes",
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
            onTap: () => setState(() => currentLevel2 = null),
          ),
        ),
        Divider(height: 1, color: Colors.black.withValues(alpha: 0.06)),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: l3Data.map((item) {
              final fullPath = "$currentLevel1 > $currentLevel2 > $item";
              final isSelected = selectedGeneralZones.contains(fullPath);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  gradient: isSelected ? AppColors.painGradient.scale(0.3) : null,
                  color: isSelected ? null : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.painStart.withValues(alpha: 0.5)
                        : Colors.grey.shade200,
                    width: 1.5,
                  ),
                ),
                child: CheckboxListTile(
                  title: Text(
                    item,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? AppColors.painEnd : Colors.black87,
                    ),
                  ),
                  value: isSelected,
                  activeColor: AppColors.painEnd,
                  checkColor: Colors.white,
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
}
