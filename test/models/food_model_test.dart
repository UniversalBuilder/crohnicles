import 'package:flutter_test/flutter_test.dart';
import 'package:crohnicles/food_model.dart';

void main() {
  group('FoodModel', () {
    test('toMap converts all fields correctly', () {
      final food = FoodModel(
        id: 1,
        name: 'Poulet',
        category: 'Protéine',
        tags: ['Viande', 'Fait-maison'],
        proteins: 25.0,
        fats: 10.0,
        carbs: 0.0,
        fiber: 0.0,
        sugars: 0.0,
        brand: 'Test Brand',
        imageUrl: 'http://example.com/image.jpg',
        barcode: '1234567890123',
      );

      final map = food.toMap();

      expect(map['id'], 1);
      expect(map['name'], 'Poulet');
      expect(map['category'], 'Protéine');
      expect(map['tags'], 'Viande,Fait-maison');
      expect(map['proteins'], 25.0);
      expect(map['barcode'], '1234567890123');
    });

    test('fromMap reconstructs FoodModel correctly', () {
      final map = {
        'id': 2,
        'name': 'Pâtes',
        'category': 'Féculent',
        'tags': 'Gluten,Industriel',
        'proteins': 12.0,
        'fats': 2.0,
        'carbs': 70.0,
        'fiber': 3.0,
        'sugars': 2.0,
      };

      final food = FoodModel.fromMap(map);

      expect(food.id, 2);
      expect(food.name, 'Pâtes');
      expect(food.tags, ['Gluten', 'Industriel']);
      expect(food.carbs, 70.0);
    });

    test('Tags are parsed and stored correctly', () {
      final food1 = FoodModel(
        id: 1,
        name: 'Test',
        category: 'Snack',
        tags: ['Tag1', 'Tag2', 'Tag3'],
      );

      final map = food1.toMap();
      final food2 = FoodModel.fromMap(map);

      expect(food2.tags, ['Tag1', 'Tag2', 'Tag3']);
    });

    test('Nullable nutrition fields default to null', () {
      final food = FoodModel(
        id: 1,
        name: 'Unknown Food',
        category: 'Snack',
        tags: [],
      );

      expect(food.proteins, null);
      expect(food.fats, null);
      expect(food.barcode, null);
    });
  });
}
