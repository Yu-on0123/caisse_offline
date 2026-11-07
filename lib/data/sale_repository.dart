import 'package:sqflite/sqflite.dart';

import '../core/ids_time.dart';
import 'models/sale.dart';
import 'outbox_repository.dart';

class SaleRepository {
  SaleRepository(this._db, this._onWrite);

  final Database _db;
  final void Function() _onWrite;

  Future<List<Sale>> recent({int limit = 200}) async {
    final rows = await _db.query(
      'sales',
      where: 'deleted_at IS NULL',
      orderBy: 'sold_at DESC',
      limit: limit,
    );
    if (rows.isEmpty) return [];

    final ids = rows.map((r) => r['id'] as String).toList();
    final placeholders = List.filled(ids.length, '?').join(',');
    final itemRows = await _db.rawQuery(
      'SELECT * FROM sale_items WHERE sale_id IN ($placeholders)',
      ids,
    );
    final bySale = <String, List<SaleItem>>{};
    for (final row in itemRows) {
      final item = SaleItem.fromMap(row);
      (bySale[item.saleId] ??= []).add(item);
    }
    return rows
        .map((r) => Sale.fromMap(r, bySale[r['id'] as String] ?? const <SaleItem>[]))
        .toList();
  }

  Future<Sale> create({
    required List<CartLine> lines,
    String? note,
    DateTime? soldAt,
  }) async {
    final now = nowIso();
    final saleId = newId();
    final items = [
      for (final line in lines)
        SaleItem(
          id: newId(),
          saleId: saleId,
          productId: line.productId,
          productName: line.name,
          unitPrice: line.unitPrice,
          quantity: line.quantity,
        ),
    ];
    final total = items.fold<int>(0, (sum, item) => sum + item.lineTotal);
    final cleanedNote = note?.trim();
    final sale = Sale(
      id: saleId,
      total: total,
      note: (cleanedNote == null || cleanedNote.isEmpty) ? null : cleanedNote,
      soldAt: soldAt == null ? now : toIso(soldAt),
      createdAt: now,
      updatedAt: now,
      items: items,
    );
    await _save(sale);
    return sale;
  }

  Future<void> delete(Sale sale) {
    final now = nowIso();
    return _save(sale.copyWith(updatedAt: now, deletedAt: now));
  }

  Future<void> _save(Sale sale) async {
    await _db.transaction((txn) async {
      await txn.insert(
        'sales',
        sale.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete('sale_items', where: 'sale_id = ?', whereArgs: [sale.id]);
      for (final item in sale.items) {
        await txn.insert('sale_items', item.toMap());
      }
      await OutboxRepository.enqueue(
        txn,
        entity: 'sale',
        entityId: sale.id,
        payload: sale.toJson(),
        updatedAt: sale.updatedAt,
      );
    });
    _onWrite();
  }
}
