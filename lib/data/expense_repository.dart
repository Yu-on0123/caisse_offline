import 'package:sqflite/sqflite.dart';

import '../core/ids_time.dart';
import 'models/expense.dart';
import 'outbox_repository.dart';

class ExpenseRepository {
  ExpenseRepository(this._db, this._onWrite);

  final Database _db;
  final void Function() _onWrite;

  Future<List<Expense>> recent({int limit = 200}) async {
    final rows = await _db.query(
      'expenses',
      where: 'deleted_at IS NULL',
      orderBy: 'spent_at DESC',
      limit: limit,
    );
    return rows.map(Expense.fromMap).toList();
  }

  Future<Expense> create({
    required String category,
    required int amount,
    String? note,
    DateTime? spentAt,
  }) async {
    final now = nowIso();
    final cleanedNote = note?.trim();
    final expense = Expense(
      id: newId(),
      category: category,
      amount: amount,
      note: (cleanedNote == null || cleanedNote.isEmpty) ? null : cleanedNote,
      spentAt: spentAt == null ? now : toIso(spentAt),
      createdAt: now,
      updatedAt: now,
    );
    await _save(expense);
    return expense;
  }

  Future<void> delete(Expense expense) {
    final now = nowIso();
    return _save(expense.copyWith(updatedAt: now, deletedAt: now));
  }

  Future<void> _save(Expense expense) async {
    await _db.transaction((txn) async {
      await txn.insert(
        'expenses',
        expense.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await OutboxRepository.enqueue(
        txn,
        entity: 'expense',
        entityId: expense.id,
        payload: expense.toMap(),
        updatedAt: expense.updatedAt,
      );
    });
    _onWrite();
  }
}
