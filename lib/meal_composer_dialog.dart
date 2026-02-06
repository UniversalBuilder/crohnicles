import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart'
    as mlkit;
import 'database_helper.dart';
import 'food_model.dart';
import 'themes/app_gradients.dart';
import 'event_model.dart';
import 'services/off_service.dart';
import 'services/food_recognizer.dart';
import 'utils/platform_utils.dart';
import 'utils/validators.dart';

class MealComposerDialog extends StatefulWidget {
  final EventModel? existingEvent;

  const MealComposerDialog({super.key, this.existingEvent});

  @override
  // ignore: library_private_types_in_public_api
  _MealComposerDialogState createState() => _MealComposerDialogState();
}

class _MealComposerDialogState extends State<MealComposerDialog>
    with SingleTickerProviderStateMixin {
  final List<FoodModel> _cart = [];
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<bool> _hasSearchText = ValueNotifier<bool>(false);
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late TabController _tabController;
  bool _isSnack = false;
  DateTime _selectedDate = DateTime.now();
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
      _selectedDate = event.timestamp;
      isEditMode = true;

      // Parse foods from meta_data
      if (event.metaData != null && event.metaData!.isNotEmpty) {
        try {
          final metadata = jsonDecode(event.metaData!);
          if (metadata['foods'] is List) {
            for (var foodJson in metadata['foods']) {
              try {
                _cart.add(FoodModel.fromMap(foodJson));
              } catch (e) {
                debugPrint('[MEAL EDIT] Failed to parse food: $e');
              }
            }
          }
        } catch (e) {
          debugPrint('[MEAL EDIT] Failed to parse meta_data: $e');
        }
      }
    }

    // Initialize TabController with initial index based on edit mode
    // In edit mode, start on Cart tab to show the cart
    // In create mode, start on Search tab (faster, no camera overhead)
    final bool isMobile = PlatformUtils.isMobile;
    final int tabCount = isMobile ? 4 : 3;
    final int cartIndex = isMobile ? 3 : 2;

    // Default start tab: Search tab (1 on Mobile because Scanner is index 0, 0 on Desktop)
    // PERF: Skip Scanner tab by default to avoid camera + ML initialization overhead
    int initialIndex = isMobile ? 1 : 0;

    if (isEditMode && _cart.isNotEmpty) {
      initialIndex = cartIndex;
    }

    _tabController = TabController(
      length: tabCount,
      vsync: this,
      initialIndex: initialIndex,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    _hasSearchText.dispose();
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

    // Minimum 2 caractères pour recherche (performances)
    if (query.length < 2) {
      setState(() {
        _localResults = [];
      });
      return;
    }

    final localResults = await _dbHelper.searchFoods(query);
    debugPrint('[SEARCH] Local DB: ${localResults.length} results for "$query"');

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
      debugPrint('[SEARCH] 🔍 Recherche OpenFoodFacts: "$_currentQuery"');
      final offResults = await OFFService().searchProducts(_currentQuery);
      debugPrint('[SEARCH] OpenFoodFacts: ${offResults.length} results');

      if (mounted) {
        setState(() {
          _offResults = offResults; // NO CLIENT FILTERING - API already did it
          _hasSearchedOFF = true;
          _isSearchingOFF = false;
        });
      }
    } catch (e) {
      debugPrint('[SEARCH] OpenFoodFacts error: $e');
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

    // Trigger local search with debounce (2000ms pour performances critiques)
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 2000), () {
      // Minimum 2 caractères pour recherche DB (optimisation performances)
      if (query.length >= 2) {
        _searchLocal(query);
      } else if (query.isEmpty) {
        _searchLocal(query); // Clear results
      }
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
          debugPrint('[CART] 💾 Saved OFF product to local DB: ${food.name}');
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
                    var newFood = FoodModel(
                      id: 0,
                      name: name,
                      category: selectedCategory,
                      tags: selectedTags,
                    );
                    final id = await _dbHelper.insertFood(newFood);
                    if (!mounted) return;
                    
                    // Update food with valid ID
                    newFood = FoodModel(
                      id: id,
                      name: name,
                      category: selectedCategory,
                      tags: selectedTags,
                    );

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
    // 1. Validate date (not in future, max 2 years old)
    final dateError = EventValidators.validateEventDate(_selectedDate);
    if (dateError != null) {
      EventValidators.showValidationError(context, dateError);
      return;
    }

    // 2. Validate cart (non-empty with valid quantities)
    final cartError = EventValidators.validateMealCart(_cart);
    if (cartError != null) {
      EventValidators.showValidationError(context, cartError);
      return;
    }

    final allTags = _recalculateTags();

    // Return raw objects, let the caller handle serialization
    final result = {
      'foods': _cart
          .map((f) => f.toMap())
          .toList(), // List<Map<String, dynamic>>
      'tags': allTags,
      'is_snack': _isSnack,
      'timestamp': _selectedDate,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.surface.withValues(alpha: 0.95),
              colorScheme.surface.withValues(alpha: 0.85),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: colorScheme.surface.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppGradients.meal(brightness).colors.first.withValues(alpha: 0.3),
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
                decoration: BoxDecoration(gradient: AppGradients.meal(brightness)),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.surface.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.restaurant_menu,
                            color: colorScheme.onPrimary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Composer un Repas',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: colorScheme.onPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: colorScheme.onPrimary),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // SegmentedButton for Repas/Snack
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withValues(alpha: 0.2),
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
                              return colorScheme.surface;
                            }
                            return Colors.transparent;
                          }),
                          foregroundColor: WidgetStateProperty.resolveWith((
                            states,
                          ) {
                            if (states.contains(WidgetState.selected)) {
                              return colorScheme.secondary;
                            }
                            return colorScheme.onPrimary;
                          }),
                        ),
                      ),
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
                                  return MediaQuery(
                                    data: MediaQuery.of(context).copyWith(
                                      alwaysUse24HourFormat: true,
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

              // TabBar
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
                  labelColor: colorScheme.secondary,
                  unselectedLabelColor: colorScheme.onSurfaceVariant,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    gradient: AppGradients.meal(brightness).scale(0.15),
                    border: Border(
                      bottom: BorderSide(
                        color: colorScheme.secondary,
                        width: 3,
                      ),
                    ),
                  ),
                  labelStyle: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: [
                    if (PlatformUtils.isMobile)
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
                    if (PlatformUtils.isMobile)
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
                  color: colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.onSurface.withValues(alpha: 0.05),
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
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppGradients.meal(brightness),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.secondary.withValues(alpha: 0.4),
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
                              Icon(
                                Icons.check,
                                color: colorScheme.onPrimary,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _isSnack ? 'Valider Snack' : 'Valider Repas',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onPrimary,
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
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
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

                  debugPrint('[SCANNER] Barcode detected: $code');

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
              color: colorScheme.surface.withValues(alpha: 0.95),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Scannez le code-barres d\'un produit',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ou utilisez 📷 pour sélectionner une image',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
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
            backgroundColor: colorScheme.secondary,
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
              backgroundColor: colorScheme.tertiary,
            ),
          ),
      ],
    );
  }

  void _showManualBarcodeDialog(String imagePath) {
    final TextEditingController barcodeController = TextEditingController();
    final dialogTheme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Entrer le code-barres',
          style: dialogTheme.textTheme.titleMedium,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Saisissez le code-barres visible sur la photo',
              style: dialogTheme.textTheme.bodyMedium?.copyWith(
                color: dialogTheme.colorScheme.onSurfaceVariant,
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
                helperStyle: dialogTheme.textTheme.bodySmall,
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
                if (!mounted) return;
                
                if (food != null) {
                  setState(() {
                    _cart.add(food);
                  });
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ ${food.name} ajouté')),
                  );
                } else {
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

    final dialogTheme = Theme.of(context);
    
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
              style: dialogTheme.textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );

    String? detectedBarcode;
    bool barcodeDetectionAvailable = false;

    // Step 1: Try barcode detection (mobile only)
    if (PlatformUtils.isMobile) {
      barcodeDetectionAvailable = true;
      try {
        detectedBarcode = await _detectBarcode(imagePath);
        debugPrint(
          '[ImageAnalysis] Barcode detection result: ${detectedBarcode ?? "none"}',
        );
      } catch (e) {
        debugPrint('[ImageAnalysis] Barcode detection failed: $e');
      }
    }

    // Step 2: If barcode found, try OpenFoodFacts
    if (detectedBarcode != null) {
      try {
        final product = await OFFService().fetchByBarcode(detectedBarcode);
        if (!mounted) return;
        Navigator.pop(context); // Close loading

        if (product != null) {
          debugPrint('[ImageAnalysis] Product found via barcode: ${product.name}');
          _addToCart(product);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('✅ ${product.name} ajouté')));
          return;
        } else {
          debugPrint('[ImageAnalysis] Barcode not found in OpenFoodFacts');
        }
      } catch (e) {
        debugPrint('[ImageAnalysis] OpenFoodFacts error: $e');
      }
    }

    // Step 3: No barcode or not found -> try food recognition
    // Note: TFLite food recognition disabled on Windows (missing DLL)
    // Works on Android/iOS platforms
    if (mounted && PlatformUtils.isMobile) {
      try {
        debugPrint('[ImageAnalysis] Loading TFLite model...');
        final recognizer = FoodRecognizer();
        await recognizer.loadModel();

        debugPrint('[ImageAnalysis] Running inference...');
        final predictions = await recognizer.recognizeFood(imagePath);

        if (!mounted) return;
        Navigator.pop(context); // Close loading

        if (predictions.isNotEmpty) {
          debugPrint(
            '[ImageAnalysis] Top 3: ${predictions.take(3).map((p) => "${p.foodName} ${(p.confidence * 100).toStringAsFixed(1)}%").join(", ")}',
          );
        }

        // Lower threshold to 10% to detect more foods
        if (predictions.isNotEmpty && predictions.first.confidence > 0.10) {
          debugPrint(
            '[ImageAnalysis] Showing predictions (best: ${(predictions.first.confidence * 100).toStringAsFixed(1)}%)',
          );
          _showFoodPredictionsDialog(predictions, imagePath);
          return;
        } else {
          debugPrint(
            '[ImageAnalysis] Confidence too low (${predictions.isNotEmpty ? (predictions.first.confidence * 100).toStringAsFixed(1) : 0}%), manual fallback',
          );
        }
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context); // Close loading
      }
    } else {
      // On Windows: skip food recognition, go directly to manual
      if (!mounted) return;
      // On Windows: skip food recognition, go directly to manual
      Navigator.pop(context); // Close loading
      debugPrint(
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
        debugPrint(
          '[BarcodeDetection] Detected: $barcode (type: ${barcodes.first.format})',
        );
        return barcode;
      }

      debugPrint('[BarcodeDetection] No barcode found in image');
      return null;
    } finally {
      scanner.close();
    }
  }

  /// Show dialog with food recognition predictions (with multi-select)
  void _showFoodPredictionsDialog(List<dynamic> predictions, String imagePath) {
    final selectedIndices = <int>{};
    final dialogTheme = Theme.of(context);
    final dialogColorScheme = dialogTheme.colorScheme;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.auto_awesome, color: dialogColorScheme.tertiary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Aliments détectés (${predictions.length})',
                  style: dialogTheme.textTheme.titleMedium?.copyWith(
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
                  style: dialogTheme.textTheme.bodyMedium?.copyWith(
                    color: dialogColorScheme.onSurfaceVariant,
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
                          backgroundColor: dialogColorScheme.secondary.withValues(alpha: 0.2),
                          child: Text(
                            '$confidence%',
                            style: dialogTheme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: dialogColorScheme.secondary,
                            ),
                          ),
                        ),
                        title: Text(
                          foodName,
                          style: dialogTheme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Confiance: $confidence%',
                          style: dialogTheme.textTheme.bodySmall,
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 24),
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.close,
                    color: dialogColorScheme.tertiary,
                    size: 20,
                  ),
                  title: Text(
                    'Aucun de ces aliments',
                    style: dialogTheme.textTheme.bodyMedium?.copyWith(
                      color: dialogColorScheme.tertiary,
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
              child: Text('Annuler', style: dialogTheme.textTheme.bodyMedium),
            ),
            ElevatedButton(
              onPressed: selectedIndices.isEmpty
                  ? null
                  : () async {
                      // Add all selected foods
                      for (final index in selectedIndices) {
                        final foodModel = await _createFoodModelFromPrediction(
                          predictions[index],
                        );
                        setState(() => _cart.add(foodModel));
                      }

                      if (!mounted) return;
                      Navigator.pop(context);
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '✅ ${selectedIndices.length} aliment(s) ajouté(s)',
                          ),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: dialogColorScheme.secondary,
              ),
              child: Text(
                'Ajouter (${selectedIndices.length})',
                style: dialogTheme.textTheme.bodyMedium?.copyWith(
                  color: dialogColorScheme.onSecondary,
                ),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar
          Text(
            'Rechercher un aliment',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          _buildAutocomplete(),

          const SizedBox(height: 24),

          // Local results section
          if (_currentQuery.isNotEmpty && _localResults.isNotEmpty) ...[
            Text(
              'Résultats locaux (${_localResults.length})',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
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
                    backgroundColor: colorScheme.secondary,
                    foregroundColor: colorScheme.onSecondary,
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
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
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
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
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
                    Icon(Icons.search, size: 48, color: colorScheme.outline),
                    const SizedBox(height: 16),
                    Text(
                      'Tapez pour rechercher un aliment',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
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
                color: colorScheme.secondary,
              ),
        title: Text(
          food.name,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: food.brand != null
            ? Text(
                food.brand!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.add_circle),
          color: colorScheme.secondary,
          onPressed: () => _addToCart(food),
        ),
      ),
    );
  }

  // Tab 3: Manual Creation
  Widget _buildCreateTab() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
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
                style: theme.textTheme.titleMedium,
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
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
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
                    backgroundColor: colorScheme.surface,
                    selectedColor: colorScheme.secondary.withValues(alpha: 0.2),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Tags
              Text(
                'Tags (optionnel)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
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
                    if (!mounted) return;
                    
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
                    backgroundColor: colorScheme.secondary,
                    foregroundColor: colorScheme.onSecondary,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Ex: Pâtes, Poulet, Pomme...',
        prefixIcon: ShaderMask(
          shaderCallback: (bounds) =>
              AppGradients.meal(brightness).createShader(bounds),
          child: Icon(Icons.search, color: colorScheme.surface),
        ),
        suffixIcon: ValueListenableBuilder<bool>(
          valueListenable: _hasSearchText,
          builder: (context, hasText, child) {
            return hasText
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      _hasSearchText.value = false;
                      _search(''); // Clear results
                    },
                  )
                : const SizedBox.shrink();
          },
        ),
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colorScheme.secondary,
            width: 2,
          ),
        ),
      ),
      onChanged: (value) {
        // Update notifier (no setState = no rebuild = performance boost)
        _hasSearchText.value = value.isNotEmpty;
        _search(value);
      },
      onSubmitted: (value) {
        _searchOpenFoodFacts();
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;

    if (widget.cart.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Panier vide',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ajoutez des aliments depuis les autres onglets',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.outline,
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
                        : AppGradients.meal(brightness).scale(0.3),
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
                                  gradient: AppGradients.meal(brightness).scale(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.fastfood,
                                  color: colorScheme.onPrimary,
                                  size: 30,
                                ),
                              );
                            },
                          ),
                        )
                      : Icon(
                          Icons.fastfood,
                          color: colorScheme.onPrimary,
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
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (food.brand != null && food.brand!.isNotEmpty)
                        Text(
                          food.brand!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        food.category,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.secondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Remove button
                IconButton(
                  icon: Icon(Icons.delete_outline, color: colorScheme.error),
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

