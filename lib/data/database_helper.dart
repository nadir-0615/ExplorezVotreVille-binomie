import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// =========================================================
/// DATABASE HELPER - Gestion SQLite complète (AMÉLIORÉ)
/// =========================================================
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('explorez_ville.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path,
        version: 2, onCreate: _createDB, onUpgrade: _onUpgrade);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE villes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        pays TEXT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        est_favorite INTEGER DEFAULT 0,
        est_principale INTEGER DEFAULT 0,
        date_ajout TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE lieux (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        titre TEXT NOT NULL,
        categorie TEXT NOT NULL,
        images_urls TEXT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        commentaire TEXT,
        note REAL,
        ville_id INTEGER NOT NULL,
        date_ajout TEXT NOT NULL,
        FOREIGN KEY (ville_id) REFERENCES villes (id) ON DELETE CASCADE
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migration : remplacer image_url par images_urls
      await db
          .execute('ALTER TABLE lieux RENAME COLUMN image_url TO images_urls');
    }
  }

  // ========== VILLES ==========

  Future<int> insertVille({
    required String nom,
    String? pays,
    required double latitude,
    required double longitude,
    bool estFavorite = false,
    bool estPrincipale = false,
  }) async {
    final db = await database;
    if (estPrincipale) {
      await db.update('villes', {'est_principale': 0});
    }
    return await db.insert('villes', {
      'nom': nom,
      'pays': pays,
      'latitude': latitude,
      'longitude': longitude,
      'est_favorite': estFavorite ? 1 : 0,
      'est_principale': estPrincipale ? 1 : 0,
      'date_ajout': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getVillesFavorites() async {
    final db = await database;
    return await db.query('villes',
        where: 'est_favorite = ?', whereArgs: [1], orderBy: 'date_ajout DESC');
  }

  Future<Map<String, dynamic>?> getVillePrincipale() async {
    final db = await database;
    final result = await db.query('villes',
        where: 'est_principale = ?', whereArgs: [1], limit: 1);
    return result.isNotEmpty ? result.first : null;
  }

  Future<void> setVillePrincipale(int villeId) async {
    final db = await database;
    await db.update('villes', {'est_principale': 0});
    await db.update('villes', {'est_principale': 1},
        where: 'id = ?', whereArgs: [villeId]);
  }

  Future<void> toggleFavorite(int villeId, bool isFavorite) async {
    final db = await database;
    await db.update('villes', {'est_favorite': isFavorite ? 1 : 0},
        where: 'id = ?', whereArgs: [villeId]);
  }

  Future<Map<String, dynamic>?> getVilleByNom(String nom) async {
    final db = await database;
    final result =
        await db.query('villes', where: 'nom = ?', whereArgs: [nom], limit: 1);
    return result.isNotEmpty ? result.first : null;
  }

  Future<void> deleteVille(int villeId) async {
    final db = await database;
    await db.delete('villes', where: 'id = ?', whereArgs: [villeId]);
  }

  // ========== LIEUX ==========

  Future<int> insertLieu({
    required String titre,
    required String categorie,
    List<String>? imagesUrls,
    required double latitude,
    required double longitude,
    String? commentaire,
    double? note,
    required int villeId,
  }) async {
    final db = await database;

    final imageUrlsString = imagesUrls != null && imagesUrls.isNotEmpty
        ? imagesUrls.join('|||')
        : '';

    print('💾 Insertion en DB: $titre, categorie=$categorie, ville=$villeId');

    final id = await db.insert('lieux', {
      'titre': titre,
      'categorie': categorie,
      'images_urls': imageUrlsString,
      'latitude': latitude,
      'longitude': longitude,
      'commentaire': commentaire,
      'note': note,
      'ville_id': villeId,
      'date_ajout': DateTime.now().toIso8601String(),
    });

    print('✅ Lieu inséré avec ID: $id');

    return id;
  }

  Future<List<Map<String, dynamic>>> getLieuxByVille(int villeId) async {
    final db = await database;
    return await db.query('lieux',
        where: 'ville_id = ?',
        whereArgs: [villeId],
        orderBy: 'date_ajout DESC');
  }

  Future<List<Map<String, dynamic>>> getLieuxByCategorie(
      int villeId, String categorie) async {
    final db = await database;
    return await db.query('lieux',
        where: 'ville_id = ? AND categorie = ?',
        whereArgs: [villeId, categorie],
        orderBy: 'date_ajout DESC');
  }

  Future<void> deleteLieu(int lieuId) async {
    final db = await database;
    await db.delete('lieux', where: 'id = ?', whereArgs: [lieuId]);
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}
