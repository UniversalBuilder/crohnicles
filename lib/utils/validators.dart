/// Validateurs pour les entrées utilisateur
/// 
/// Règles de validation claires et messages d'erreur en français
/// pour garantir l'intégrité des données saisies.
import 'package:flutter/material.dart';
import '../food_model.dart';

class EventValidators {
  /// Valide une date d'événement
  /// 
  /// Règles :
  /// - Ne peut pas être dans le futur
  /// - Ne peut pas être antérieure à 2 ans (données trop anciennes)
  /// 
  /// Returns: null si valide, message d'erreur sinon
  static String? validateEventDate(DateTime date) {
    final now = DateTime.now();
    final twoYearsAgo = now.subtract(const Duration(days: 730));
    
    if (date.isAfter(now)) {
      return '❌ La date ne peut pas être dans le futur';
    }
    
    if (date.isBefore(twoYearsAgo)) {
      return '❌ Les données de plus de 2 ans ne sont pas acceptées';
    }
    
    return null; // Valide
  }
  
  /// Valide une sévérité de symptôme
  /// 
  /// Règles :
  /// - Doit être entre 1 et 10
  /// 
  /// Returns: null si valide, message d'erreur sinon
  static String? validateSeverity(int severity) {
    if (severity < 1 || severity > 10) {
      return '❌ La sévérité doit être entre 1 et 10';
    }
    return null;
  }
  
  /// Valide une quantité (portion, grammes, ml)
  /// 
  /// Règles :
  /// - Doit être > 0
  /// - Maximum raisonnable : 2000g ou 2000ml
  /// 
  /// Returns: null si valide, message d'erreur sinon
  static String? validateQuantity(double quantity, {String unit = 'g'}) {
    if (quantity <= 0) {
      return '❌ La quantité doit être supérieure à 0';
    }
    
    if (quantity > 2000) {
      return '❌ Quantité trop élevée (max 2000$unit)';
    }
    
    return null;
  }
  
  /// Valide le panier de repas
  /// 
  /// Règles :
  /// - Ne peut pas être vide
  /// - Chaque aliment doit avoir une quantité valide (servingSize par défaut = 100g)
  /// 
  /// Returns: null si valide, message d'erreur sinon
  static String? validateMealCart(List<FoodModel> cart) {
    if (cart.isEmpty) {
      return '❌ Ajoutez au moins un aliment au repas';
    }
    
    // Note: servingSize par défaut = 100g (voir FoodModel constructor)
    // Validation: accepter toutes valeurs raisonnables
    for (final food in cart) {
      if (food.servingSize > 5000) {
        return '❌ ${food.name} : quantité maximale 5000g/ml';
      }
    }
    
    return null;
  }
  
  /// Valide un texte requis (titre, notes, etc.)
  /// 
  /// Règles :
  /// - Ne peut pas être vide ou uniquement des espaces
  /// - Longueur minimale : 1 caractère
  /// - Longueur maximale : 200 caractères
  /// 
  /// Returns: null si valide, message d'erreur sinon
  static String? validateRequiredText(String? text, {String fieldName = 'Champ'}) {
    if (text == null || text.trim().isEmpty) {
      return '❌ $fieldName requis';
    }
    
    if (text.length > 200) {
      return '❌ $fieldName trop long (max 200 caractères)';
    }
    
    return null;
  }
  
  /// Valide une échelle Bristol (selles)
  /// 
  /// Règles :
  /// - Doit être entre 1 et 7
  /// 
  /// Returns: null si valide, message d'erreur sinon
  static String? validateBristolScale(int scale) {
    if (scale < 1 || scale > 7) {
      return '❌ L\'échelle de Bristol doit être entre 1 et 7';
    }
    return null;
  }
  
  /// Valide une liste de tags
  /// 
  /// Règles :
  /// - Minimum 1 tag pour symptômes
  /// - Chaque tag doit faire au moins 2 caractères
  /// 
  /// Returns: null si valide, message d'erreur sinon
  static String? validateTags(List<String> tags, {bool required = false}) {
    if (required && tags.isEmpty) {
      return '❌ Sélectionnez au moins un tag';
    }
    
    for (final tag in tags) {
      if (tag.trim().length < 2) {
        return '❌ Tag trop court : "$tag"';
      }
    }
    
    return null;
  }
  
  /// Valide une zone anatomique pour les symptômes
  /// 
  /// Règles :
  /// - Si fournie, ne doit pas être vide
  /// 
  /// Returns: null si valide, message d'erreur sinon
  static String? validateAnatomicalZone(String? zone) {
    if (zone != null && zone.trim().isEmpty) {
      return '❌ Zone anatomique invalide';
    }
    return null;
  }
  
  /// Affiche un SnackBar d'erreur de validation
  /// 
  /// Utilitaire pour afficher les erreurs de manière cohérente
  static void showValidationError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
