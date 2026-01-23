import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'database_helper.dart';
import 'food_model.dart';
import 'app_theme.dart';
import 'services/off_service.dart';

class MealComposerDialog extends StatefulWidget {
  const MealComposerDialog({Key? key}) : super(key: key);

  @override
  _MealComposerDialogState createState() => _MealComposerDialogState();
}

class _MealComposerDialogState extends State<MealComposerDialog>
    with SingleTickerProviderStateMixin {
  final List<FoodModel> _cart = [];
  final TextEditingController _searchController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late TabController _tabController;
  bool _isSnack = false;

  String? _selectedCategoryFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<Iterable<FoodModel>> _search(String query) async {
    if (query.isEmpty) return [];
    var results = await _dbHelper.searchFoods(query);
    if (_selectedCategoryFilter != null) {
      results = results
          .where((f) => f.category == _selectedCategoryFilter)
          .toList();
    }
    return results;
  }

  void _addToCart(FoodModel food) {
    setState(() {
      _cart.add(food);
      _searchController.clear();
    });
  }

  void _removeFromCart(FoodModel food) {
    setState(() {
      _cart.remove(food);
    });
  }

  // ignore: unused_element
  Future<void> _createNewFood(String name) async {
    String selectedCategory = 'Snack';
    final List<String> availableTags = [
      'Gluten',
      'Lactose',
      'Sucre',
      'Gras',
      'Fait-maison',
      'Industriel',
      'Épicé',
      'Caféine',
      'Alcool',
    ];
    final List<String> selectedTags = [];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text("Créer '$name'"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    items: ['Boisson', 'Féculent', 'Protéine', 'Snack', 'Repas']
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) =>
                        setStateDialog(() => selectedCategory = v!),
                    decoration: const InputDecoration(labelText: 'Catégorie'),
                  ),
                  const SizedBox(height: 16),
                  Text("Tags:", style: Theme.of(context).textTheme.bodyMedium),
                  Wrap(
                    spacing: 8.0,
                    children: availableTags.map((tag) {
                      final isSelected = selectedTags.contains(tag);
                      return FilterChip(
                        label: Text(tag),
                        selected: isSelected,
                        onSelected: (bool selected) {
                          setStateDialog(() {
                            if (selected) {
                              selectedTags.add(tag);
                            } else {
                              selectedTags.remove(tag);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final newFood = FoodModel(
                      id: 0,
                      name: name,
                      category: selectedCategory,
                      tags: selectedTags,
                    );
                    await _dbHelper.insertFood(newFood);
                    if (mounted) {
                      Navigator.pop(context);
                      _addToCart(newFood);
                    }
                  },
                  child: const Text('Créer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _validateMeal() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins un aliment')),
      );
      return;
    }

    final List<String> allTags = <String>{
      for (var food in _cart) ...food.tags,
    }.toList();

    final result = {
      'foods': jsonEncode(_cart.map((f) => f.toMap()).toList()),
      'tags': allTags,
      'is_snack': _isSnack,
    };

    Navigator.pop(context, result);
  }

  // ignore: unused_element
  Future<void> _scanBarcode() async {
    // Scanner will be handled in the scanner tab
  }

  Icon _getCategoryIcon(String? category) {
    switch (category) {
      case 'Boisson':
        return const Icon(Icons.local_drink, size: 16);
      case 'Féculent':
        return const Icon(Icons.grain, size: 16);
      case 'Protéine':
        return const Icon(Icons.egg, size: 16);
      case 'Snack':
        return const Icon(Icons.cookie, size: 16);
      case 'Repas':
        return const Icon(Icons.restaurant, size: 16);
      default:
        return const Icon(Icons.fastfood, size: 16);
    }
  }

  Widget _buildCategoryChip(String category) {
    final isSelected = _selectedCategoryFilter == category;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _getCategoryIcon(category),
          const SizedBox(width: 4),
          Text(category),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedCategoryFilter = selected ? category : null;
        });
      },
      backgroundColor: Colors.white,
      selectedColor: AppColors.mealGradient.colors.first.withValues(alpha: 0.2),
      checkmarkColor: AppColors.mealGradient.colors.last,
      side: BorderSide(
        color: isSelected
            ? AppColors.mealGradient.colors.first
            : Colors.grey.shade300,
        width: 1.5,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.95),
              Colors.white.withValues(alpha: 0.85),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.mealGradient.colors.first.withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Column(
            children: [
              // Gradient Header with SegmentedButton
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(gradient: AppColors.mealGradient),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.restaurant_menu,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Composer un Repas',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // SegmentedButton for Repas/Snack
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: false,
                            label: Text('Repas'),
                            icon: Icon(Icons.restaurant, size: 18),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text('Snack'),
                            icon: Icon(Icons.cookie, size: 18),
                          ),
                        ],
                        selected: {_isSnack},
                        onSelectionChanged: (Set<bool> newSelection) {
                          setState(() {
                            _isSnack = newSelection.first;
                          });
                        },
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.resolveWith((
                            states,
                          ) {
                            if (states.contains(WidgetState.selected)) {
                              return Colors.white;
                            }
                            return Colors.transparent;
                          }),
                          foregroundColor: WidgetStateProperty.resolveWith((
                            states,
                          ) {
                            if (states.contains(WidgetState.selected)) {
                              return AppColors.mealGradient.colors.first;
                            }
                            return Colors.white;
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // TabBar
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
                  labelColor: AppColors.mealGradient.colors.first,
                  unselectedLabelColor: Colors.grey.shade600,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    gradient: AppColors.mealGradient.scale(0.15),
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.mealGradient.colors.first,
                        width: 3,
                      ),
                    ),
                  ),
                  labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.qr_code_scanner, size: 20),
                      text: "Scanner",
                    ),
                    Tab(icon: Icon(Icons.search, size: 20), text: "Rechercher"),
                    Tab(
                      icon: Icon(Icons.add_circle_outline, size: 20),
                      text: "Créer",
                    ),
                  ],
                ),
              ),

              // Content with TabBarView
              Expanded(
                child: Column(
                  children: [
                    // Cart display at the top if not empty
                    if (_cart.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: AppColors.surfaceGlass,
                        child: _buildCartDisplay(),
                      ),
                    // TabBarView
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildScannerTab(),
                          _buildSearchTab(),
                          _buildCreateTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Action Buttons
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                      child: Text(
                        'Annuler',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.mealGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.mealGradient.colors.first
                                .withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _validateMeal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              _isSnack
                                  ? 'Valider le Snack'
                                  : 'Valider le Repas',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ],
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
    );
  }

  // Tab 1: Barcode Scanner
  Widget _buildScannerTab() {
    return Column(
      children: [
        Expanded(
          child: MobileScanner(
            onDetect: (capture) async {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;

              final String? code = barcodes.first.rawValue;
              if (code == null) return;

              print('[SCANNER] Barcode detected: $code');

              // Fetch product from OpenFoodFacts
              final food = await OFFService().fetchByBarcode(code);
              if (food != null && mounted) {
                _addToCart(food);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${food.name} ajouté au panier')),
                );
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Produit non trouvé')),
                );
              }
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white.withValues(alpha: 0.95),
          child: Text(
            'Scannez le code-barres d\'un produit',
            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade700),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  // Tab 2: Search (existing functionality)
  Widget _buildSearchTab() {
    return Column(
      children: [
        // Category Filter Pills
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          color: AppColors.surfaceGlass,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryChip('Boisson'),
                const SizedBox(width: 8),
                _buildCategoryChip('Féculent'),
                const SizedBox(width: 8),
                _buildCategoryChip('Protéine'),
                const SizedBox(width: 8),
                _buildCategoryChip('Snack'),
                const SizedBox(width: 8),
                _buildCategoryChip('Repas'),
                if (_selectedCategoryFilter != null) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Effacer'),
                    onPressed: () {
                      setState(() {
                        _selectedCategoryFilter = null;
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        // Search and results (keep existing code structure but moved here)
        Expanded(
          child: Container(
            color: AppColors.surfaceGlass,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cart Display
                if (_cart.isNotEmpty) ...[
                  _buildCartDisplay(),
                  const SizedBox(height: 16),
                ],
                // Search Bar
                Text(
                  'Rechercher un aliment',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                _buildAutocomplete(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Tab 3: Manual Creation
  Widget _buildCreateTab() {
    final TextEditingController nameController = TextEditingController();
    String selectedCategory = 'Snack';
    final List<String> selectedTags = [];
    final List<String> availableTags = [
      'Gluten',
      'Lactose',
      'Sucre',
      'Gras',
      'Fait-maison',
      'Industriel',
      'Épicé',
      'Bio',
      'Protéine',
      'Féculent',
    ];

    return StatefulBuilder(
      builder: (context, setDialogState) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Créer un nouvel aliment',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),

              // Name field
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nom de l\'aliment',
                  hintText: 'Ex: Pizza maison',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  prefixIcon: const Icon(Icons.restaurant),
                ),
              ),
              const SizedBox(height: 16),

              // Category selector
              Text(
                'Catégorie',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['Boisson', 'Féculent', 'Protéine', 'Snack', 'Repas']
                    .map((cat) {
                      final isSelected = selectedCategory == cat;
                      return FilterChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _getCategoryIcon(cat),
                            const SizedBox(width: 4),
                            Text(cat),
                          ],
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          setDialogState(() {
                            selectedCategory = cat;
                          });
                        },
                        backgroundColor: Colors.white,
                        selectedColor: AppColors.mealGradient.colors.first
                            .withValues(alpha: 0.2),
                      );
                    })
                    .toList(),
              ),
              const SizedBox(height: 16),

              // Tags
              Text(
                'Tags (optionnel)',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableTags.map((tag) {
                  final isSelected = selectedTags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: isSelected,
                    onSelected: (selected) {
                      setDialogState(() {
                        if (selected) {
                          selectedTags.add(tag);
                        } else {
                          selectedTags.remove(tag);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Create button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Veuillez entrer un nom')),
                      );
                      return;
                    }

                    final newFood = FoodModel(
                      name: nameController.text.trim(),
                      category: selectedCategory,
                      tags: selectedTags,
                    );

                    await _dbHelper.insertFood(newFood);
                    setState(() {
                      _cart.add(newFood);
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${newFood.name} créé et ajouté')),
                    );

                    nameController.clear();
                    selectedTags.clear();
                  },
                  icon: const Icon(Icons.add_circle),
                  label: const Text('Créer et ajouter au panier'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.mealGradient.colors.first,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCartDisplay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.mealGradient.colors.first.withValues(alpha: 0.1),
            AppColors.mealGradient.colors.last.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.mealGradient.colors.first.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppColors.mealGradient.createShader(bounds),
                child: const Icon(
                  Icons.shopping_cart,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Panier (${_cart.length})',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _cart.map((food) {
              return Chip(
                avatar: ShaderMask(
                  shaderCallback: (bounds) =>
                      AppColors.mealGradient.createShader(bounds),
                  child: _getCategoryIcon(food.category),
                ),
                label: Text(
                  food.name,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => _removeFromCart(food),
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: AppColors.mealGradient.colors.first.withValues(
                    alpha: 0.3,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAutocomplete() {
    return Autocomplete<FoodModel>(
      optionsBuilder: (textEditingValue) async {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<FoodModel>.empty();
        }
        return await _search(textEditingValue.text);
      },
      displayStringForOption: (FoodModel option) => option.name,
      onSelected: (FoodModel selection) {
        _addToCart(selection);
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        _searchController.text = controller.text;
        controller.addListener(() {
          _searchController.text = controller.text;
        });
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: 'Ex: Pâtes, Poulet, Pomme...',
            prefixIcon: ShaderMask(
              shaderCallback: (bounds) =>
                  AppColors.mealGradient.createShader(bounds),
              child: const Icon(Icons.search, color: Colors.white),
            ),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      controller.clear();
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: AppColors.mealGradient.colors.first,
                width: 2,
              ),
            ),
          ),
          onSubmitted: (value) {
            onFieldSubmitted();
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 400,
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.mealGradient.colors.first.withValues(
                    alpha: 0.3,
                  ),
                  width: 1.5,
                ),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final FoodModel option = options.elementAt(index);
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.mealGradient.colors.first.withValues(
                              alpha: 0.2,
                            ),
                            AppColors.mealGradient.colors.last.withValues(
                              alpha: 0.1,
                            ),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ShaderMask(
                        shaderCallback: (bounds) =>
                            AppColors.mealGradient.createShader(bounds),
                        child: _getCategoryIcon(option.category),
                      ),
                    ),
                    title: Text(option.name),
                    subtitle: Text(
                      '${option.category} • ${option.tags.join(", ")}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    onTap: () {
                      onSelected(option);
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
