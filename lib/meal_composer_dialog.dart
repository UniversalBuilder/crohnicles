import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart'
    as mlkit;
import 'database_helper.dart';
import 'food_model.dart';
import 'app_theme.dart';
import 'event_model.dart';
import 'services/off_service.dart';
import 'services/food_recognizer.dart';

class MealComposerDialog extends StatefulWidget {
  final EventModel? existingEvent;

  const MealComposerDialog({super.key, this.existingEvent});

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
  Timer? _debounce;

  // Search state
  List<FoodModel> _localResults = [];
  List<FoodModel> _offResults = [];
  bool _isSearchingOFF = false;
  bool _hasSearchedOFF = false;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();

    // Pre-fill data if editing existing event
    bool isEditMode = false;
    if (widget.existingEvent != null) {
      final event = widget.existingEvent!;
      _isSnack = event.isSnack;
      isEditMode = true;

      // Parse foods from meta_data
      if (event.metaData != null && event.metaData!.isNotEmpty) {
        try {
          final metadata = jsonDecode(event.metaData!);
          if (metadata['foods'] is List) {
            for (var foodJson in metadata['foods']) {
              try {
                _cart.add(FoodModel.fromJson(foodJson));
              } catch (e) {
                print('[MEAL EDIT] Failed to parse food: $e');
              }
            }
          }
        } catch (e) {
          print('[MEAL EDIT] Failed to parse meta_data: $e');
        }
      }
    }

    // Initialize TabController with initial index based on edit mode
    // In edit mode, start on Cart tab (index 3) to show the cart
    // In create mode, start on Scanner tab (index 0)
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: isEditMode && _cart.isNotEmpty ? 3 : 0,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchLocal(String query) async {
    if (query.isEmpty) {
      setState(() {
        _localResults = [];
        _offResults = [];
        _hasSearchedOFF = false;
        _currentQuery = '';
      });
      return;
    }

    final localResults = await _dbHelper.searchFoods(query);
    print('[SEARCH] Local DB: ${localResults.length} results for "$query"');

    if (mounted) {
      setState(() {
        _localResults = _sortByRelevance(localResults, query);
      });
    }
  }

  Future<void> _searchOpenFoodFacts() async {
    if (_currentQuery.isEmpty || _currentQuery.length < 3) return;

    setState(() {
      _isSearchingOFF = true;
    });

    try {
      print('[SEARCH] 🔍 Recherche OpenFoodFacts: "$_currentQuery"');
      final offResults = await OFFService().searchProducts(_currentQuery);
      print('[SEARCH] OpenFoodFacts: ${offResults.length} results');

      if (mounted) {
        setState(() {
          _offResults = offResults; // NO CLIENT FILTERING - API already did it
          _hasSearchedOFF = true;
          _isSearchingOFF = false;
        });
      }
    } catch (e) {
      print('[SEARCH] OpenFoodFacts error: $e');
      if (mounted) {
        setState(() {
          _isSearchingOFF = false;
          _hasSearchedOFF = true;
        });
      }
    }
  }

  List<FoodModel> _sortByRelevance(List<FoodModel> foods, String query) {
    final queryLower = query.toLowerCase();

    // Sort by relevance: exact match > starts with > contains > alphabetical
    final sorted = foods.toList();
    sorted.sort((a, b) {
      final aName = a.name.toLowerCase();
      final bName = b.name.toLowerCase();

      // Exact match
      if (aName == queryLower && bName != queryLower) return -1;
      if (bName == queryLower && aName != queryLower) return 1;

      // Starts with
      final aStarts = aName.startsWith(queryLower);
      final bStarts = bName.startsWith(queryLower);
      if (aStarts && !bStarts) return -1;
      if (bStarts && !aStarts) return 1;

      // Contains
      final aContains = aName.contains(queryLower);
      final bContains = bName.contains(queryLower);
      if (aContains && !bContains) return -1;
      if (bContains && !aContains) return 1;

      // Alphabetical
      return aName.compareTo(bName);
    });

    return sorted;
  }

  Future<Iterable<FoodModel>> _search(String query) async {
    // Update current query immediately
    _currentQuery = query;

    // Reset OFF results when query changes
    if (mounted) {
      setState(() {
        _hasSearchedOFF = false;
        _offResults = [];
      });
    }

    // Trigger local search with debounce
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _searchLocal(query);
    });

    // Return combined results for autocomplete
    return [..._localResults, ..._offResults];
  }

  void _addToCart(FoodModel food) {
    setState(() {
      _cart.add(food);
      _searchController.clear();
    });

    // Save OFF products to local DB for future offline access
    if (food.barcode != null && food.barcode!.isNotEmpty) {
      _dbHelper.insertOrUpdateFood(food).then((added) {
        if (added) {
          print('[CART] 💾 Saved OFF product to local DB: ${food.name}');
        }
      });
    }
  }

  void _removeFromCart(FoodModel food) {
    setState(() {
      _cart.remove(food);
    });
  }

  List<String> _recalculateTags() {
    // Recalculate global tags from all cart items
    final Set<String> allTags = {};
    for (var food in _cart) {
      allTags.addAll(food.tags);
    }
    return allTags.toList();
  }

  // ignore: unused_element
  Future<void> _createNewFood(String name) async {
    String selectedCategory = 'Snack';
    final List<String> availableTags = [
      'Légume',
      'Fruit',
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
                    initialValue: selectedCategory,
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

    final allTags = _recalculateTags();

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
                  tabs: [
                    const Tab(
                      icon: Icon(Icons.qr_code_scanner, size: 20),
                      text: "Scanner",
                    ),
                    const Tab(
                      icon: Icon(Icons.search, size: 20),
                      text: "Rechercher",
                    ),
                    const Tab(
                      icon: Icon(Icons.add_circle_outline, size: 20),
                      text: "Créer",
                    ),
                    Tab(
                      icon: Badge(
                        isLabelVisible: _cart.isNotEmpty,
                        label: Text(_cart.length.toString()),
                        child: const Icon(Icons.shopping_cart, size: 20),
                      ),
                      text: "Panier",
                    ),
                  ],
                ),
              ),

              // Content with TabBarView
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildScannerTab(),
                    _buildSearchTab(),
                    _buildCreateTab(),
                    _buildCartTab(),
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
                    Flexible(
                      child: Container(
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
                              horizontal: 20,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _isSnack ? 'Valider Snack' : 'Valider Repas',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
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
    );
  }

  // Tab 1: Barcode Scanner
  Widget _buildScannerTab() {
    return Stack(
      children: [
        Column(
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Scannez le code-barres d\'un produit',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ou utilisez 📷 pour sélectionner une image',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
        // Photo upload button (right)
        Positioned(
          bottom: 100,
          right: 16,
          child: FloatingActionButton.extended(
            heroTag: 'gallery_btn',
            onPressed: () async {
              final ImagePicker picker = ImagePicker();
              final XFile? image = await picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 85,
              );

              if (image != null && mounted) {
                await _intelligentImageAnalysis(image.path);
              }
            },
            icon: const Icon(Icons.photo_library),
            label: const Text('Galerie'),
            backgroundColor: AppColors.mealGradient.colors.first,
          ),
        ),
        // Camera capture button (left) - Only on mobile platforms
        if (Theme.of(context).platform == TargetPlatform.android ||
            Theme.of(context).platform == TargetPlatform.iOS)
          Positioned(
            bottom: 100,
            left: 16,
            child: FloatingActionButton.extended(
              heroTag: 'camera_btn',
              onPressed: () async {
                final ImagePicker picker = ImagePicker();
                final XFile? image = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 85,
                );

                if (image != null && mounted) {
                  await _intelligentImageAnalysis(image.path);
                }
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text('Photo'),
              backgroundColor: AppColors.mealGradient.colors.last,
            ),
          ),
      ],
    );
  }

  void _showManualBarcodeDialog(String imagePath) {
    final TextEditingController barcodeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Entrer le code-barres',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Saisissez le code-barres visible sur la photo',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: barcodeController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Ex: 3017620422003',
                labelText: 'Code-barres (8 ou 13 chiffres)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                helperText: 'Code Coca-Cola: 5449000000996',
                helperStyle: GoogleFonts.inter(fontSize: 11),
              ),
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
              final code = barcodeController.text.trim();
              Navigator.pop(context);

              if (code.isNotEmpty) {
                // Show loading
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Recherche en cours...')),
                );

                final food = await OFFService().fetchByBarcode(code);
                if (food != null && mounted) {
                  setState(() {
                    _cart.add(food);
                  });
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ ${food.name} ajouté')),
                  );
                } else if (mounted) {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('❌ Produit non trouvé'),
                      action: SnackBarAction(
                        label: 'Créer',
                        onPressed: () {
                          _tabController.animateTo(2); // Go to Create tab
                        },
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Rechercher'),
          ),
        ],
      ),
    );
  }

  /// Intelligent image analysis workflow
  /// 1. Try barcode detection (mobile only)
  /// 2. If barcode found -> fetch from OpenFoodFacts
  /// 3. If no barcode or not found -> try food recognition
  /// 4. Fallback to manual barcode entry
  Future<void> _intelligentImageAnalysis(String imagePath) async {
    if (!mounted) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Analyse de l\'image...',
              style: GoogleFonts.poppins(fontSize: 16),
            ),
          ],
        ),
      ),
    );

    String? detectedBarcode;
    bool barcodeDetectionAvailable = false;

    // Step 1: Try barcode detection (mobile only)
    if (Platform.isAndroid || Platform.isIOS) {
      barcodeDetectionAvailable = true;
      try {
        detectedBarcode = await _detectBarcode(imagePath);
        print(
          '[ImageAnalysis] Barcode detection result: ${detectedBarcode ?? "none"}',
        );
      } catch (e) {
        print('[ImageAnalysis] Barcode detection failed: $e');
      }
    }

    // Step 2: If barcode found, try OpenFoodFacts
    if (detectedBarcode != null) {
      try {
        final product = await OFFService().fetchByBarcode(detectedBarcode);
        Navigator.pop(context); // Close loading

        if (product != null) {
          print('[ImageAnalysis] Product found via barcode: ${product.name}');
          _addToCart(product);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('✅ ${product.name} ajouté')));
          return;
        } else {
          print('[ImageAnalysis] Barcode not found in OpenFoodFacts');
        }
      } catch (e) {
        print('[ImageAnalysis] OpenFoodFacts error: $e');
      }
    }

    // Step 3: No barcode or not found -> try food recognition
    // Note: TFLite food recognition disabled on Windows (missing DLL)
    // Works on Android/iOS platforms
    if (mounted && (Platform.isAndroid || Platform.isIOS)) {
      try {
        print('[ImageAnalysis] Loading TFLite model...');
        final recognizer = FoodRecognizer();
        await recognizer.loadModel();

        print('[ImageAnalysis] Running inference...');
        final predictions = await recognizer.recognizeFood(imagePath);

        Navigator.pop(context); // Close loading

        if (predictions.isNotEmpty) {
          print(
            '[ImageAnalysis] Top 3: ${predictions.take(3).map((p) => "${p.foodName} ${(p.confidence * 100).toStringAsFixed(1)}%").join(", ")}',
          );
        }

        // Lower threshold to 10% to detect more foods
        if (predictions.isNotEmpty && predictions.first.confidence > 0.10) {
          print(
            '[ImageAnalysis] Showing predictions (best: ${(predictions.first.confidence * 100).toStringAsFixed(1)}%)',
          );
          _showFoodPredictionsDialog(predictions, imagePath);
          return;
        } else {
          print(
            '[ImageAnalysis] Confidence too low (${predictions.isNotEmpty ? (predictions.first.confidence * 100).toStringAsFixed(1) : 0}%), manual fallback',
          );
        }
      } catch (e) {
        print('[ImageAnalysis] Food recognition failed: $e');
        Navigator.pop(context); // Close loading
      }
    } else if (mounted) {
      // On Windows: skip food recognition, go directly to manual
      Navigator.pop(context); // Close loading
      print(
        '[ImageAnalysis] Food recognition not available on Windows - skipping',
      );
    }

    // Step 4: Fallback to manual entry
    if (mounted) {
      if (barcodeDetectionAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '⚠️ Aucun aliment reconnu. Veuillez saisir manuellement.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
      _showManualBarcodeDialog(imagePath);
    }
  }

  /// Detect barcode from image file using Google ML Kit
  Future<String?> _detectBarcode(String imagePath) async {
    final inputImage = mlkit.InputImage.fromFilePath(imagePath);
    final scanner = mlkit.BarcodeScanner(
      formats: [mlkit.BarcodeFormat.ean8, mlkit.BarcodeFormat.ean13],
    );

    try {
      final barcodes = await scanner.processImage(inputImage);

      if (barcodes.isNotEmpty) {
        final barcode = barcodes.first.rawValue;
        print(
          '[BarcodeDetection] Detected: $barcode (type: ${barcodes.first.format})',
        );
        return barcode;
      }

      print('[BarcodeDetection] No barcode found in image');
      return null;
    } finally {
      scanner.close();
    }
  }

  /// Show dialog with food recognition predictions (with multi-select)
  void _showFoodPredictionsDialog(List<dynamic> predictions, String imagePath) {
    final selectedIndices = <int>{};

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.purple, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Aliments détectés (${predictions.length})',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sélectionnez les aliments à ajouter :',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: predictions.take(5).length,
                    itemBuilder: (context, index) {
                      final pred = predictions[index];
                      final confidence = (pred.confidence * 100)
                          .toStringAsFixed(0);
                      final foodName = pred.foodName
                          .split(' ')
                          .map(
                            (w) => w.isEmpty
                                ? ''
                                : w[0].toUpperCase() + w.substring(1),
                          )
                          .join(' ');

                      return CheckboxListTile(
                        value: selectedIndices.contains(index),
                        onChanged: (checked) {
                          setStateDialog(() {
                            if (checked!) {
                              selectedIndices.add(index);
                            } else {
                              selectedIndices.remove(index);
                            }
                          });
                        },
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        secondary: CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.mealGradient.colors.first
                              .withValues(alpha: 0.2),
                          child: Text(
                            '$confidence%',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.mealGradient.colors.first,
                            ),
                          ),
                        ),
                        title: Text(
                          foodName,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Confiance: $confidence%',
                          style: GoogleFonts.inter(fontSize: 11),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 24),
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.close,
                    color: Colors.orange,
                    size: 20,
                  ),
                  title: Text(
                    'Aucun de ces aliments',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.orange,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showManualBarcodeDialog(imagePath);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler', style: GoogleFonts.inter(fontSize: 13)),
            ),
            ElevatedButton(
              onPressed: selectedIndices.isEmpty
                  ? null
                  : () async {
                      Navigator.pop(context);

                      // Add all selected foods
                      for (final index in selectedIndices) {
                        final foodModel = await _createFoodModelFromPrediction(
                          predictions[index],
                        );
                        setState(() => _cart.add(foodModel));
                      }

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '✅ ${selectedIndices.length} aliment(s) ajouté(s)',
                            ),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mealGradient.colors.first,
              ),
              child: Text(
                'Ajouter (${selectedIndices.length})',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Create FoodModel from prediction
  Future<FoodModel> _createFoodModelFromPrediction(dynamic prediction) async {
    final foodName = prediction.foodName
        .split(' ')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');

    final category = _inferCategory(prediction.foodName);
    final confidence = (prediction.confidence * 100).toStringAsFixed(0);

    return FoodModel(
      id: null,
      name: foodName,
      category: category,
      tags: ['IA Détecté', '$confidence% confiance'],
      proteins: null,
      fats: null,
      carbs: null,
      fiber: null,
      sugars: null,
      brand: null,
      imageUrl: null,
      barcode: null,
    );
  }

  /// Infer category from food name
  String _inferCategory(String foodName) {
    final lower = foodName.toLowerCase();

    if (lower.contains('salad')) return 'Légumes';
    if (lower.contains('cake') ||
        lower.contains('dessert') ||
        lower.contains('ice cream') ||
        lower.contains('pudding') ||
        lower.contains('mousse') ||
        lower.contains('tiramisu') ||
        lower.contains('donut') ||
        lower.contains('macaron')) {
      return 'Dessert';
    }
    if (lower.contains('pizza') ||
        lower.contains('burger') ||
        lower.contains('sandwich') ||
        lower.contains('hot dog') ||
        lower.contains('fries')) {
      return 'Fast-Food';
    }
    if (lower.contains('chicken') ||
        lower.contains('beef') ||
        lower.contains('pork') ||
        lower.contains('steak') ||
        lower.contains('ribs') ||
        lower.contains('lamb')) {
      return 'Viande';
    }
    if (lower.contains('fish') ||
        lower.contains('salmon') ||
        lower.contains('sushi') ||
        lower.contains('sashimi') ||
        lower.contains('shrimp') ||
        lower.contains('lobster') ||
        lower.contains('oyster') ||
        lower.contains('scallop')) {
      return 'Poisson';
    }
    if (lower.contains('rice') ||
        lower.contains('pasta') ||
        lower.contains('noodle') ||
        lower.contains('spaghetti') ||
        lower.contains('ramen') ||
        lower.contains('gnocchi')) {
      return 'Féculent';
    }
    if (lower.contains('bread') ||
        lower.contains('toast') ||
        lower.contains('pancake') ||
        lower.contains('waffle') ||
        lower.contains('bagel') ||
        lower.contains('croissant')) {
      return 'Pain';
    }
    if (lower.contains('soup') ||
        lower.contains('chowder') ||
        lower.contains('bisque') ||
        lower.contains('broth')) {
      return 'Soupe';
    }
    if (lower.contains('water') ||
        lower.contains('juice') ||
        lower.contains('soda') ||
        lower.contains('coffee') ||
        lower.contains('tea')) {
      return 'Boisson';
    }

    return 'Plat Préparé';
  }

  // Tab 2: Search (existing functionality)
  Widget _buildSearchTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

          const SizedBox(height: 24),

          // Local results section
          if (_currentQuery.isNotEmpty && _localResults.isNotEmpty) ...[
            Text(
              'Résultats locaux (${_localResults.length})',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            ..._localResults.map((food) => _buildFoodCard(food)),
          ],

          // OpenFoodFacts section
          if (_currentQuery.length >= 3) ...[
            const SizedBox(height: 16),

            // OFF button or results
            if (!_hasSearchedOFF) ...[
              Center(
                child: ElevatedButton.icon(
                  onPressed: _searchOpenFoodFacts,
                  icon: const Icon(Icons.cloud_download),
                  label: const Text('Rechercher sur OpenFoodFacts'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mealGradient.colors.first,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Show loading or results
              if (_isSearchingOFF)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_offResults.isNotEmpty) ...[
                Text(
                  'OpenFoodFacts (${_offResults.length})',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                ..._offResults.map((food) => _buildFoodCard(food)),
              ] else
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      'Aucun résultat trouvé sur OpenFoodFacts',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
            ],
          ],

          // Empty state
          if (_currentQuery.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(48.0),
                child: Column(
                  children: [
                    Icon(Icons.search, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'Tapez pour rechercher un aliment',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFoodCard(FoodModel food) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: food.imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  food.imageUrl!,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.restaurant),
                ),
              )
            : Icon(
                _getCategoryIcon(food.category).icon,
                color: AppColors.mealGradient.colors.first,
              ),
        title: Text(
          food.name,
          style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        subtitle: food.brand != null
            ? Text(
                food.brand!,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              )
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.add_circle),
          color: AppColors.mealGradient.colors.first,
          onPressed: () => _addToCart(food),
        ),
      ),
    );
  }

  // Tab 3: Manual Creation
  Widget _buildCreateTab() {
    final TextEditingController nameController = TextEditingController();
    String selectedCategory = 'Repas';
    final List<String> selectedTags = [];
    final List<String> availableTags = [
      // Tags nutritionnels
      'Protéine',
      'Glucides',
      'Lipides',
      'Fibres',
      // Tags qualitatifs
      'Gluten',
      'Lactose',
      'Gras',
      'Épicé',
      'Alcool',
      'Gaz',
      // Tags d'identification
      'Fruit',
      'Légume',
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
                children: ['Repas', 'En-cas', 'Boisson'].map((cat) {
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
                }).toList(),
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
        // Clear search field after adding to cart
        _searchController.clear();
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
                  final isFromOFF =
                      option.barcode != null && option.barcode!.isNotEmpty;

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
                        child: Icon(
                          isFromOFF ? Icons.cloud_done : Icons.restaurant,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            option.name,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isFromOFF)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Text(
                              'OFF',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      '${option.category}${option.tags.isNotEmpty ? " • ${option.tags.join(", ")}" : ""}',
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

  Widget _buildCartTab() {
    return _CartTabContent(cart: _cart, onRemove: _removeFromCart);
  }
}

// Separate widget with AutomaticKeepAliveClientMixin for cart persistence
class _CartTabContent extends StatefulWidget {
  final List<FoodModel> cart;
  final Function(FoodModel) onRemove;

  const _CartTabContent({required this.cart, required this.onRemove});

  @override
  State<_CartTabContent> createState() => _CartTabContentState();
}

class _CartTabContentState extends State<_CartTabContent>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    if (widget.cart.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Panier vide',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ajoutez des aliments depuis les autres onglets',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.cart.length,
      itemBuilder: (context, index) {
        final food = widget.cart[index];
        final hasImage = food.imageUrl != null && food.imageUrl!.isNotEmpty;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Food image or icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: hasImage
                        ? null
                        : AppColors.mealGradient.scale(0.3),
                  ),
                  child: hasImage
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            food.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                decoration: BoxDecoration(
                                  gradient: AppColors.mealGradient.scale(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.fastfood,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              );
                            },
                          ),
                        )
                      : const Icon(
                          Icons.fastfood,
                          color: Colors.white,
                          size: 30,
                        ),
                ),
                const SizedBox(width: 12),
                // Food details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food.name,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (food.brand != null && food.brand!.isNotEmpty)
                        Text(
                          food.brand!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        food.category,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.mealGradient.colors.first,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Remove button
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                  onPressed: () => widget.onRemove(food),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
