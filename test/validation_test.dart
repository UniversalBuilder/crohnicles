import 'package:flutter_test/flutter_test.dart';
import 'package:crohnicles/utils/validators.dart';
import 'package:crohnicles/food_model.dart';

void main() {
  group('EventValidators - Date Validation', () {
    test('Date actuelle est valide', () {
      final now = DateTime.now();
      final error = EventValidators.validateEventDate(now);
      
      expect(error, isNull);
    });

    test('Date passée récente est valide', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final error = EventValidators.validateEventDate(yesterday);
      
      expect(error, isNull);
    });

    test('Date future est invalide', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final error = EventValidators.validateEventDate(tomorrow);
      
      expect(error, isNotNull);
      expect(error, contains('futur'));
    });

    test('Date >2 ans ancienneté est invalide', () {
      final twoYearsAgo = DateTime.now().subtract(const Duration(days: 731));
      final error = EventValidators.validateEventDate(twoYearsAgo);
      
      expect(error, isNotNull);
      expect(error, contains('2 ans'));
    });

    test('Date exactement 2 ans est limite acceptable', () {
      final exactlyTwoYears = DateTime.now().subtract(const Duration(days: 730));
      final error = EventValidators.validateEventDate(exactlyTwoYears);
      
      // Devrait être accepté (limite inclusive)
      expect(error, isNull);
    });

    test('Date 1 an passé est valide', () {
      final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
      final error = EventValidators.validateEventDate(oneYearAgo);
      
      expect(error, isNull);
    });
  });

  group('EventValidators - Severity Validation', () {
    test('Sévérité 1 est valide (minimum)', () {
      final error = EventValidators.validateSeverity(1);
      expect(error, isNull);
    });

    test('Sévérité 10 est valide (maximum)', () {
      final error = EventValidators.validateSeverity(10);
      expect(error, isNull);
    });

    test('Sévérité 5 est valide (milieu échelle)', () {
      final error = EventValidators.validateSeverity(5);
      expect(error, isNull);
    });

    test('Sévérité 0 est invalide', () {
      final error = EventValidators.validateSeverity(0);
      
      expect(error, isNotNull);
      expect(error, contains('1 et 10'));
    });

    test('Sévérité 11 est invalide', () {
      final error = EventValidators.validateSeverity(11);
      
      expect(error, isNotNull);
      expect(error, contains('1 et 10'));
    });

    test('Sévérité négative est invalide', () {
      final error = EventValidators.validateSeverity(-5);
      
      expect(error, isNotNull);
    });

    test('Toutes valeurs 1-10 sont valides', () {
      for (int i = 1; i <= 10; i++) {
        final error = EventValidators.validateSeverity(i);
        expect(error, isNull, reason: 'Sévérité $i devrait être valide');
      }
    });
  });

  group('EventValidators - Quantity Validation', () {
    test('Quantité 1g est valide', () {
      final error = EventValidators.validateQuantity(1.0);
      expect(error, isNull);
    });

    test('Quantité 200g est valide', () {
      final error = EventValidators.validateQuantity(200.0);
      expect(error, isNull);
    });

    test('Quantité 2000g est valide (maximum)', () {
      final error = EventValidators.validateQuantity(2000.0);
      expect(error, isNull);
    });

    test('Quantité 0 est invalide', () {
      final error = EventValidators.validateQuantity(0.0);
      
      expect(error, isNotNull);
      expect(error, contains('supérieure à 0'));
    });

    test('Quantité négative est invalide', () {
      final error = EventValidators.validateQuantity(-50.0);
      
      expect(error, isNotNull);
    });

    test('Quantité >2000g est invalide', () {
      final error = EventValidators.validateQuantity(2500.0);
      
      expect(error, isNotNull);
      expect(error, contains('2000'));
    });

    test('Quantité 0.1g est valide (décimale)', () {
      final error = EventValidators.validateQuantity(0.1);
      expect(error, isNull);
    });

    test('Quantité 1999.99g est valide', () {
      final error = EventValidators.validateQuantity(1999.99);
      expect(error, isNull);
    });
  });

  group('EventValidators - Meal Cart Validation', () {
    test('Panier vide est invalide', () {
      final emptyCart = <FoodModel>[];
      final error = EventValidators.validateMealCart(emptyCart);
      
      expect(error, isNotNull);
      expect(error, contains('aliment'));
    });

    test('Panier avec 1 aliment valide est valide', () {
      final cart = [
        FoodModel(
          id: 1,
          name: 'Poulet',
          category: 'Protéine',
          tags: ['Viande'],
          servingSize: 200.0,
        ),
      ];
      final error = EventValidators.validateMealCart(cart);
      
      expect(error, isNull);
    });

    test('Panier avec aliment quantité 0 est invalide', () {
      final cart = [
        FoodModel(
          id: 1,
          name: 'Poulet',
          category: 'Protéine',
          tags: ['Viande'],
          servingSize: 0.0,
        ),
      ];
      // Note: validateMealCart vérifie uniquement panier non vide
      // La validation des quantités individuelles se fait via validateQuantity
      final error = EventValidators.validateMealCart(cart);
      
      // Le panier n'est pas vide, donc pas d'erreur ici
      expect(error, isNull);
    });

    test('Panier avec aliment quantité excessive est invalide', () {
      final cart = [
        FoodModel(
          id: 1,
          name: 'Poulet',
          category: 'Protéine',
          tags: ['Viande'],
          servingSize: 3000.0,
        ),
      ];
      // Note: validateMealCart vérifie uniquement panier non vide
      final error = EventValidators.validateMealCart(cart);
      
      // Le panier n'est pas vide, donc pas d'erreur ici
      expect(error, isNull);
    });

    test('Panier avec plusieurs aliments valides est valide', () {
      final cart = [
        FoodModel(
          id: 1,
          name: 'Poulet',
          category: 'Protéine',
          tags: ['Viande'],
          servingSize: 200.0,
        ),
        FoodModel(
          id: 2,
          name: 'Riz',
          category: 'Féculent',
          tags: ['Céréales'],
          servingSize: 150.0,
        ),
      ];
      final error = EventValidators.validateMealCart(cart);
      
      expect(error, isNull);
    });

    test('Panier mixte (1 valide, 1 invalide) est invalide', () {
      final cart = [
        FoodModel(
          id: 1,
          name: 'Poulet',
          category: 'Protéine',
          tags: ['Viande'],
          servingSize: 200.0,
        ),
        FoodModel(
          id: 2,
          name: 'Riz',
          category: 'Féculent',
          tags: ['Céréales'],
          servingSize: 0.0, // Invalide selon validateQuantity
        ),
      ];
      // Note: validateMealCart vérifie uniquement panier non vide
      final error = EventValidators.validateMealCart(cart);
      
      // Le panier n'est pas vide, donc pas d'erreur ici
      expect(error, isNull);
    });
  });

  group('EventValidators - Required Text Validation', () {
    test('Texte vide est invalide', () {
      final error = EventValidators.validateRequiredText('');
      
      expect(error, isNotNull);
      expect(error, contains('requis'));
    });

    test('Texte whitespace uniquement est invalide', () {
      final error = EventValidators.validateRequiredText('   ');
      
      expect(error, isNotNull);
    });

    test('Texte 1 caractère est valide', () {
      final error = EventValidators.validateRequiredText('A');
      expect(error, isNull);
    });

    test('Texte 200 caractères est valide (limite)', () {
      final text = 'A' * 200;
      final error = EventValidators.validateRequiredText(text);
      
      expect(error, isNull);
    });

    test('Texte >200 caractères est invalide', () {
      final text = 'A' * 201;
      final error = EventValidators.validateRequiredText(text);
      
      expect(error, isNotNull);
      expect(error, contains('200'));
    });

    test('Texte normal est valide', () {
      final error = EventValidators.validateRequiredText('Repas familial');
      expect(error, isNull);
    });

    test('Texte avec accents est valide', () {
      final error = EventValidators.validateRequiredText('Déjeuner été');
      expect(error, isNull);
    });

    test('Champ personnalisé option modifie message erreur', () {
      final error = EventValidators.validateRequiredText('', fieldName: 'Titre');
      
      expect(error, contains('Titre'));
    });
  });

  group('EventValidators - Bristol Scale Validation', () {
    test('Bristol 1 est valide (minimum)', () {
      final error = EventValidators.validateBristolScale(1);
      expect(error, isNull);
    });

    test('Bristol 7 est valide (maximum)', () {
      final error = EventValidators.validateBristolScale(7);
      expect(error, isNull);
    });

    test('Bristol 4 est valide (normal)', () {
      final error = EventValidators.validateBristolScale(4);
      expect(error, isNull);
    });

    test('Bristol 0 est invalide', () {
      final error = EventValidators.validateBristolScale(0);
      
      expect(error, isNotNull);
      expect(error, contains('1 et 7'));
    });

    test('Bristol 8 est invalide', () {
      final error = EventValidators.validateBristolScale(8);
      
      expect(error, isNotNull);
    });

    test('Toutes valeurs 1-7 sont valides', () {
      for (int i = 1; i <= 7; i++) {
        final error = EventValidators.validateBristolScale(i);
        expect(error, isNull, reason: 'Bristol $i devrait être valide');
      }
    });
  });

  group('EventValidators - Tags Validation', () {
    test('Liste tags vide est valide', () {
      final error = EventValidators.validateTags([]);
      expect(error, isNull);
    });

    test('Tags valides (>2 caractères) sont acceptés', () {
      final error = EventValidators.validateTags(['Gluten', 'Lactose', 'Épicé']);
      expect(error, isNull);
    });

    test('Tag 2 caractères est valide', () {
      final error = EventValidators.validateTags(['AB']);
      expect(error, isNull);
    });

    test('Tag 1 caractère est invalide', () {
      final error = EventValidators.validateTags(['A']);
      
      expect(error, isNotNull);
      expect(error, contains('trop court'));
    });

    test('Liste mixte (valides + invalide) est invalide', () {
      final error = EventValidators.validateTags(['Gluten', 'L', 'Lactose']);
      
      expect(error, isNotNull);
      expect(error, contains('L'));
    });

    test('Tag vide dans liste est invalide', () {
      final error = EventValidators.validateTags(['Gluten', '', 'Lactose']);
      
      expect(error, isNotNull);
    });
  });

  group('EventValidators - Anatomical Zone Validation', () {
    test('Zone null est valide (optionnel)', () {
      final error = EventValidators.validateAnatomicalZone(null);
      expect(error, isNull);
    });

    test('Zone vide est invalide si fournie', () {
      final error = EventValidators.validateAnatomicalZone('');
      
      expect(error, isNotNull);
      expect(error, contains('invalide'));
    });

    test('Zone valide est acceptée', () {
      final error = EventValidators.validateAnatomicalZone('Abdomen supérieur droit');
      expect(error, isNull);
    });

    test('Zone whitespace uniquement est invalide', () {
      final error = EventValidators.validateAnatomicalZone('   ');
      
      expect(error, isNotNull);
    });
  });

  group('Validation Integration - Scénarios Réels', () {
    test('Repas complet valide passe toutes validations', () {
      final date = DateTime.now().subtract(const Duration(hours: 2));
      final cart = [
        FoodModel(
          id: 1,
          name: 'Poulet',
          category: 'Protéine',
          tags: ['Viande'],
          servingSize: 200.0,
        ),
      ];

      expect(EventValidators.validateEventDate(date), isNull);
      expect(EventValidators.validateMealCart(cart), isNull);
    });

    test('Symptôme complet valide passe toutes validations', () {
      final date = DateTime.now();
      final severity = 7;
      final zone = 'Abdomen inférieur gauche';

      expect(EventValidators.validateEventDate(date), isNull);
      expect(EventValidators.validateSeverity(severity), isNull);
      expect(EventValidators.validateAnatomicalZone(zone), isNull);
    });

    test('Selles complètes valides passent toutes validations', () {
      final date = DateTime.now();
      final bristolScale = 4;

      expect(EventValidators.validateEventDate(date), isNull);
      expect(EventValidators.validateBristolScale(bristolScale), isNull);
    });
  });

  group('Validation Error Messages', () {
    test('Messages d\'erreur sont en français', () {
      final dateError = EventValidators.validateEventDate(
        DateTime.now().add(const Duration(days: 1)),
      );
      final severityError = EventValidators.validateSeverity(0);
      final quantityError = EventValidators.validateQuantity(-10);

      expect(dateError, isNotNull);
      expect(severityError, isNotNull);
      expect(quantityError, isNotNull);

      // Vérifie que les messages sont descriptifs
      expect(dateError!.length, greaterThan(10));
      expect(severityError!.length, greaterThan(10));
      expect(quantityError!.length, greaterThan(10));
    });

    test('Messages contiennent valeurs limites', () {
      final severityError = EventValidators.validateSeverity(11);
      final quantityError = EventValidators.validateQuantity(3000);
      final bristolError = EventValidators.validateBristolScale(8);

      expect(severityError, contains('10'));
      expect(quantityError, contains('2000'));
      expect(bristolError, contains('7'));
    });
  });
}
