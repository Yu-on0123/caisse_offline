import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Ouverture et schéma de la base SQLite locale.
///
/// Règles du schéma (nécessaires à la synchronisation) :
///  - clés primaires TEXT = UUID générés par l'app ;
///  - created_at / updated_at / deleted_at (suppression logique) partout ;
///  - table `outbox` : file des modifications à envoyer au serveur.
class AppDatabase {
  static const _version = 1;

  static Future<Database> open() async {
    // Sur le web : simple nom (IndexedDB). Ailleurs : chemin fichier classique.
    final String path = kIsWeb
        ? 'caisse.db'
        : p.join(await getDatabasesPath(), 'caisse.db');

    return openDatabase(
      path,
      version: _version,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        price INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        total INTEGER NOT NULL,
        note TEXT,
        sold_at TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE sale_items (
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
        product_id TEXT,
        product_name TEXT NOT NULL,
        unit_price INTEGER NOT NULL,
        quantity INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        amount INTEGER NOT NULL,
        note TEXT,
        spent_at TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE outbox (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        payload TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_sales_sold_at ON sales(sold_at)');
    await db.execute('CREATE INDEX idx_expenses_spent_at ON expenses(spent_at)');
    await db.execute('CREATE INDEX idx_sale_items_sale ON sale_items(sale_id)');
    await db.execute('CREATE INDEX idx_outbox_entity ON outbox(entity, entity_id)');
  }
}