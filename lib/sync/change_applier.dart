import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../data/models/expense.dart';
import '../data/models/product.dart';
import '../data/models/sale.dart';
import 'api_client.dart';
import 'sync_merge.dart';

/// Applique en base locale les changements reçus du serveur (pull).
class ChangeApplier {
  ChangeApplier(this._db);

  final Database _db;

  /// Retourne true si au moins une ligne locale a été modifiée.
  Future<bool> apply(List<RemoteChange> changes) async {
    if (changes.isEmpty) return false;
    var changed = false;
    await _db.transaction((txn) async {
      for (final change in changes) {
        try {
          final applied = switch (change.entity) {
            'product' => await _product(txn, change.data),
            'sale' => await _sale(txn, change.data),
            'expense' => await _expense(txn, change.data),
            _ => false, // entité inconnue (version plus récente du serveur) : ignorée
          };
          if (applied) changed = true;
        } catch (e) {
          debugPrint('Changement ignoré (${change.entity} ${change.id}) : $e');
        }
      }
    });
    return changed;
  }

  Future<bool> _isRemoteNewer(
    DatabaseExecutor txn,
    String table,
    String id,
    String remoteUpdatedAt,
  ) async {
    final rows = await txn.query(
      table,
      columns: ['updated_at'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    final local = rows.isEmpty ? null : rows.first['updated_at'] as String;
    return SyncMerge.shouldApplyRemote(
      localUpdatedAt: local,
      remoteUpdatedAt: remoteUpdatedAt,
    );
  }

  Future<bool> _product(DatabaseExecutor txn, Map<String, dynamic> data) async {
    final remote = Product.fromJson(data);
    if (!await _isRemoteNewer(txn, 'products', remote.id, remote.updatedAt)) return false;
    await txn.insert('products', remote.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    return true;
  }

  Future<bool> _expense(DatabaseExecutor txn, Map<String, dynamic> data) async {
    final remote = Expense.fromJson(data);
    if (!await _isRemoteNewer(txn, 'expenses', remote.id, remote.updatedAt)) return false;
    await txn.insert('expenses', remote.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    return true;
  }

  Future<bool> _sale(DatabaseExecutor txn, Map<String, dynamic> data) async {
    final remote = Sale.fromJson(data);
    if (!await _isRemoteNewer(txn, 'sales', remote.id, remote.updatedAt)) return false;
    await txn.insert('sales', remote.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await txn.delete('sale_items', where: 'sale_id = ?', whereArgs: [remote.id]);
    for (final item in remote.items) {
      await txn.insert('sale_items', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    return true;
  }
}
