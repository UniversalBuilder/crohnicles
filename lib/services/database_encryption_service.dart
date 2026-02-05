import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;

/// Service gérant le chiffrement de la base de données
/// 
/// Fonctionnalités :
/// - Génération et stockage sécurisé de clés de chiffrement
/// - Migration depuis DB non-chiffrée vers DB chiffrée
/// - Activation/désactivation du chiffrement
class DatabaseEncryptionService {
  static const String _encryptionKeyStorageKey = 'crohnicles_db_encryption_key';
  static const String _encryptionEnabledKey = 'crohnicles_encryption_enabled';
  
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  /// Vérifie si le chiffrement est activé
  Future<bool> isEncryptionEnabled() async {
    final enabled = await _secureStorage.read(key: _encryptionEnabledKey);
    return enabled == 'true';
  }

  /// Récupère ou génère une clé de chiffrement
  Future<String> getOrCreateEncryptionKey() async {
    String? key = await _secureStorage.read(key: _encryptionKeyStorageKey);
    
    if (key == null || key.isEmpty) {
      key = _generateSecureKey();
      await _secureStorage.write(key: _encryptionKeyStorageKey, value: key);
    }
    
    return key;
  }

  /// Génère une clé de chiffrement sécurisée (32 caractères alphanumériques)
  String _generateSecureKey() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Active le chiffrement et migre les données
  /// 
  /// Workflow :
  /// 1. Supprimer anciens fichiers temporaires (évite corruption)
  /// 2. Créer nouvelle DB chiffrée SANS onCreate
  /// 3. Créer manuellement la structure des tables
  /// 4. Copier toutes les données
  /// 5. Remplacer ancienne DB
  /// 6. Marquer chiffrement comme activé
  Future<EncryptionResult> enableEncryption({
    required Database currentDb,
    required String databasePath,
    required int version,
    required Future<void> Function(Database, int) onCreate,
    required Future<void> Function(Database, int, int) onUpgrade,
  }) async {
    try {
      final encryptionKey = await getOrCreateEncryptionKey();
      final encryptedPath = '${databasePath}_encrypted';
      
      print('[ENCRYPTION] Démarrage migration vers DB chiffrée...');
      
      // 1. CRITIQUE: Supprimer anciens fichiers temporaires pour éviter blocages
      final tempFiles = [
        encryptedPath,
        '$encryptedPath-shm',
        '$encryptedPath-wal',
      ];
      for (final path in tempFiles) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          print('[ENCRYPTION] Supprimé ancien fichier temporaire: $path');
        }
      }
      
      // 2. Ouvrir DB chiffrée SANS onCreate pour éviter erreurs sqlite_master
      final encryptedDb = await sqlcipher.openDatabase(
        encryptedPath,
        version: version,
        password: encryptionKey,
        singleInstance: false, // Permet d'avoir 2 connexions ouvertes
      );
      
      print('[ENCRYPTION] DB chiffrée ouverte avec succès');
      
      // 3. Créer manuellement la structure en copiant depuis la source
      print('[ENCRYPTION] Création structure tables...');
      await _createTablesStructure(encryptedDb);
      
      // 3. Copier les données table par table
      final tables = ['events', 'foods', 'products_cache', 'correlation_cache', 
                     'macro_thresholds', 'ml_feedback'];
      
      int totalRows = 0;
      for (final table in tables) {
        try {
          final data = await currentDb.query(table);
          if (data.isNotEmpty) {
            totalRows += data.length;
            final batch = encryptedDb.batch();
            for (final row in data) {
              batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
            }
            await batch.commit(noResult: true);
            print('[ENCRYPTION] ✓ Copié ${data.length} lignes de $table');
          } else {
            print('[ENCRYPTION] Table $table vide, skip');
          }
        } catch (e) {
          print('[ENCRYPTION] ⚠️ Erreur sur table $table: $e');
          // Continuer même si une table échoue
        }
      }

      await encryptedDb.close();
      await currentDb.close();

      // 3. Remplacer ancienne DB par nouvelle
      final dbFile = File(databasePath);
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      
      final encryptedFile = File(encryptedPath);
      await encryptedFile.rename(databasePath);

      // 4. Marquer comme activé
      await _secureStorage.write(key: _encryptionEnabledKey, value: 'true');

      return EncryptionResult(
        success: true,
        message: 'Chiffrement activé avec succès. $totalRows lignes migrées.',
      );
    } catch (e) {
      return EncryptionResult(
        success: false,
        message: 'Erreur lors du chiffrement : $e',
      );
    }
  }

  /// Désactive le chiffrement et migre vers DB non-chiffrée
  Future<EncryptionResult> disableEncryption({
    required sqlcipher.Database currentDb,
    required String databasePath,
    required int version,
    required Future<void> Function(Database, int) onCreate,
    required Future<void> Function(Database, int, int) onUpgrade,
  }) async {
    try {
      final unencryptedPath = '${databasePath}_unencrypted';
      
      print('[ENCRYPTION] Démarrage migration vers DB non-chiffrée...');
      
      // 1. CRITIQUE: Supprimer anciens fichiers temporaires
      final tempFiles = [
        unencryptedPath,
        '$unencryptedPath-shm',
        '$unencryptedPath-wal',
      ];
      for (final path in tempFiles) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          print('[ENCRYPTION] Supprimé ancien fichier temporaire: $path');
        }
      }
      
      // 2. Créer DB non-chiffrée vide avec structure
      final unencryptedDb = await openDatabase(
        unencryptedPath,
        version: version,
        onCreate: onCreate,
        onUpgrade: onUpgrade,
      );

      // 2. Copier les données table par table
      final tables = ['events', 'foods', 'products_cache', 'correlation_cache',
                     'macro_thresholds', 'ml_feedback'];
      
      for (final table in tables) {
        try {
          final data = await currentDb.query(table);
          if (data.isNotEmpty) {
            final batch = unencryptedDb.batch();
            for (final row in data) {
              batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
            }
            await batch.commit(noResult: true);
            print('[ENCRYPTION] ✓ Copié ${data.length} lignes de $table');
          } else {
            print('[ENCRYPTION] Table $table vide, skip');
          }
        } catch (e) {
          print('[ENCRYPTION] ⚠️ Erreur sur table $table: $e');
          // Continuer même si une table échoue
        }
      }

      await unencryptedDb.close();
      await currentDb.close();

      // 3. Remplacer DB chiffrée par nouvelle
      final dbFile = File(databasePath);
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      
      final unencryptedFile = File(unencryptedPath);
      await unencryptedFile.rename(databasePath);

      // 4. Marquer comme désactivé
      await _secureStorage.write(key: _encryptionEnabledKey, value: 'false');

      return EncryptionResult(
        success: true,
        message: 'Chiffrement désactivé. Données migrées.',
      );
    } catch (e) {
      return EncryptionResult(
        success: false,
        message: 'Erreur lors de la désactivation : $e',
      );
    }
  }

  /// Supprime définitivement la clé de chiffrement (RGPD - droit à l'oubli)
  Future<void> deleteEncryptionKey() async {
    await _secureStorage.delete(key: _encryptionKeyStorageKey);
    await _secureStorage.delete(key: _encryptionEnabledKey);
  }

  /// Crée la structure des tables dans une DB vide
  /// (sans appeler onCreate pour éviter conflits sqlite_master avec SQLCipher)
  Future<void> _createTablesStructure(Database db) async {
    // Table events
    await db.execute('''
      CREATE TABLE IF NOT EXISTS events(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT,
        dateTime TEXT,
        title TEXT,
        subtitle TEXT,
        severity INTEGER,
        tags TEXT,
        isUrgent INTEGER,
        isSnack INTEGER,
        imagePath TEXT,
        meta_data TEXT,
        context_data TEXT
      )
    ''');

    // Table foods
    await db.execute('''
      CREATE TABLE IF NOT EXISTS foods(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        category TEXT,
        tags TEXT,
        barcode TEXT,
        brand TEXT,
        imageUrl TEXT,
        energy REAL,
        proteins REAL,
        fats REAL,
        carbs REAL,
        fiber REAL,
        sugars REAL,
        nutriScore TEXT,
        novaGroup INTEGER,
        allergens TEXT,
        servingSize REAL DEFAULT 100.0,
        isBasicFood INTEGER DEFAULT 0
      )
    ''');

    // Table products_cache
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products_cache(
        barcode TEXT PRIMARY KEY,
        foodData TEXT,
        timestamp INTEGER
      )
    ''');

    // Table correlation_cache
    await db.execute('''
      CREATE TABLE IF NOT EXISTS correlation_cache(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        feature_name TEXT,
        feature_type TEXT,
        correlation_coefficient REAL,
        p_value REAL,
        sample_size INTEGER,
        confidence_interval_low REAL,
        confidence_interval_high REAL,
        last_updated TEXT
      )
    ''');

    // Table macro_thresholds
    await db.execute('''
      CREATE TABLE IF NOT EXISTS macro_thresholds(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        macro_name TEXT,
        threshold_value REAL,
        symptom_type TEXT,
        risk_increase_pct REAL,
        baseline_rate REAL,
        elevated_rate REAL,
        sample_size INTEGER,
        confidence REAL,
        last_updated TEXT
      )
    ''');

    // Table ml_feedback
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ml_feedback(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        meal_assessment_id INTEGER,
        symptom_id INTEGER,
        predicted_risk REAL,
        predicted_severity REAL,
        actual_severity REAL,
        user_validation TEXT,
        outcome_match_score REAL,
        time_delta_minutes INTEGER,
        timestamp TEXT
      )
    ''');

    // Table training_history (ML training logs)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS training_history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        trained_at TEXT,
        symptom_type TEXT,
        accuracy REAL,
        precision_score REAL,
        recall REAL,
        f1_score REAL,
        training_examples INTEGER,
        test_examples INTEGER,
        model_version TEXT,
        notes TEXT
      )
    ''');
    
    print('[ENCRYPTION] Structure des tables créée (7 tables + training_history)');
  }

  /// Ouvre une base de données (chiffrée ou non selon config)
  Future<Database> openDatabaseWithEncryption({
    required String path,
    required int version,
    required Future<void> Function(Database, int) onCreate,
    required Future<void> Function(Database, int, int) onUpgrade,
  }) async {
    final isEncrypted = await isEncryptionEnabled();
    
    if (isEncrypted) {
      final key = await getOrCreateEncryptionKey();
      return await sqlcipher.openDatabase(
        path,
        version: version,
        password: key,
        onCreate: onCreate,
        onUpgrade: onUpgrade,
      );
    } else {
      return await openDatabase(
        path,
        version: version,
        onCreate: onCreate,
        onUpgrade: onUpgrade,
      );
    }
  }
}

/// Résultat d'une opération de chiffrement
class EncryptionResult {
  final bool success;
  final String message;

  EncryptionResult({required this.success, required this.message});
}
