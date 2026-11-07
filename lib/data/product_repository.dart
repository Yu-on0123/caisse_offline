import 'package:sqflite/sqflite.dart';

import '../core/ids_time.dart';
import 'models/product.dart';
import 'outbox_repository.dart';

class ProductRepository {
  ProductRepository(this._db, this._onWrite);

  final Database _db;
  final void Function() _onWrite;

  Future<List<Product>> all() async {
    final rows = await _db.query(
      'products',
      where: 'deleted_at IS NULL',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(Product.fromMap).toList();
  }

  Future<Product> create({required String name, required int price}) async {
    final now = nowIso();
    final product = Product(
      id: newId(),
      name: name.trim(),
      price: price,
      createdAt: now,
      updatedAt: now,
    );
    await _save(product);
    return product;
  }

  Future<void> update(Product product, {required String name, required int price}) =>
      _save(product.copyWith(name: name.trim(), price: price, updatedAt: nowIso()));

  /// Suppression logique : la ligne reste en base pour pouvoir être propagée.
  Future<void> delete(Product product) {
    final now = nowIso();
    return _save(product.copyWith(updatedAt: now, deletedAt: now));
  }

  Future<void> _save(Product product) async {
    await _db.transaction((txn) async {
      await txn.insert(
        'products',
        product.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await OutboxRepository.enqueue(
        txn,
        entity: 'product',
        entityId: product.id,
        payload: product.toMap(),
        updatedAt: product.updatedAt,
      );
    });
    _onWrite();
  }
}
