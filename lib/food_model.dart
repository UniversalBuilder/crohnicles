class FoodModel {
  final int? id;
  final String name;
  final String category;
  final List<String> tags;
  
  // OpenFoodFacts fields
  final String? barcode;
  final String? brand;
  final String? imageUrl;
  
  // Nutrition per 100g
  final double? energy;        // kcal
  final double? proteins;      // g
  final double? fats;          // g
  final double? carbs;         // g
  final double? fiber;         // g
  final double? sugars;        // g
  
  // Quality indicators
  final String? nutriScore;    // 'A' to 'E'
  final int? novaGroup;        // 1 to 4
  final List<String> allergens;
  
  final double servingSize;    // default 100g
  final bool isBasicFood;      // for foods without barcode

  FoodModel({
    this.id,
    required this.name,
    required this.category,
    required this.tags,
    this.barcode,
    this.brand,
    this.imageUrl,
    this.energy,
    this.proteins,
    this.fats,
    this.carbs,
    this.fiber,
    this.sugars,
    this.nutriScore,
    this.novaGroup,
    this.allergens = const [],
    this.servingSize = 100.0,
    this.isBasicFood = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'tags': tags.join(','),
      'barcode': barcode,
      'brand': brand,
      'imageUrl': imageUrl,
      'energy': energy,
      'proteins': proteins,
      'fats': fats,
      'carbs': carbs,
      'fiber': fiber,
      'sugars': sugars,
      'nutriScore': nutriScore,
      'novaGroup': novaGroup,
      'allergens': allergens.join(','),
      'servingSize': servingSize,
      'isBasicFood': isBasicFood ? 1 : 0,
    };
  }

  factory FoodModel.fromMap(Map<String, dynamic> map) {
    return FoodModel(
      id: map['id'] as int?,
      name: map['name'] as String? ?? 'Unknown',
      category: map['category'] as String? ?? 'Autre',
      tags: map['tags'] != null 
          ? (map['tags'] as String).split(',').where((e) => e.isNotEmpty).toList()
          : [],
      barcode: map['barcode'] as String?,
      brand: map['brand'] as String?,
      imageUrl: map['imageUrl'] as String?,
      energy: map['energy'] != null ? (map['energy'] as num).toDouble() : null,
      proteins: map['proteins'] != null ? (map['proteins'] as num).toDouble() : null,
      fats: map['fats'] != null ? (map['fats'] as num).toDouble() : null,
      carbs: map['carbs'] != null ? (map['carbs'] as num).toDouble() : null,
      fiber: map['fiber'] != null ? (map['fiber'] as num).toDouble() : null,
      sugars: map['sugars'] != null ? (map['sugars'] as num).toDouble() : null,
      nutriScore: map['nutriScore'] as String?,
      novaGroup: map['novaGroup'] as int?,
      allergens: map['allergens'] != null
          ? (map['allergens'] as String).split(',').where((e) => e.isNotEmpty).toList()
          : [],
      servingSize: map['servingSize'] != null ? (map['servingSize'] as num).toDouble() : 100.0,
      isBasicFood: map['isBasicFood'] == 1,
    );
  }

  @override
  String toString() {
    return 'FoodModel{id: $id, name: $name, category: $category, tags: $tags, barcode: $barcode, brand: $brand}';
  }
}
