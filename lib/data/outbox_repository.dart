import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../core/ids_time.dart';
import 'models/outbox_op.dart';

/// File d'attente des modifications locales à envoyer au serveur.
class OutboxRepository {
  OutboxRepository(this._db);

  final Database _db;

  /// Après ce nombre d'échecs, une opération est « bloquée » jusqu'à une
  /// synchronisation manuelle.
  static const maxAttempts = 5;

  /// À appeler DANS la même transaction que l'écriture de la donnée :
  /// soit les deux sont enregistrées, soit aucune.
  ///
  /// Les opérations en attente pour la même entité sont remplacées : le
  /// payload est un instantané complet, seul le dernier état compte.
  static Future<void> enqueue(
    DatabaseExecutor executor, {
    required String entity,
    required String entityId,
    required Map<String, Object?> payload,
    required String updatedAt,
  }) async {
    await executor.delete(
      'outbox',
      where: 'entity = ? AND entity_id = ?',
      whereArgs: [entity, entityId],
    );
    await executor.insert('outbox', {
      'entity': entity,
      'entity_id': entityId,
      'payload': jsonEncode(payload),
      'updated_at': updatedAt,
      'attempts': 0,
      'created_at': nowIso(),
    });
  }

  Future<List<OutboxOp>> pending({int limit = 50}) async {
    final rows = await _db.query(
      'outbox',
      where: 'attempts < ?',
      whereArgs: [maxAttempts],
      orderBy: 'id ASC',
      limit: limit,
    );
    return rows.map(OutboxOp.fromMap).toList();
  }

  Future<int> countPending() async =>
      Sqflite.firstIntValue(await _db.rawQuery(
        'SELECT COUNT(*) FROM outbox WHERE attempts < ?',
        [maxAttempts],
      )) ??
      0;

  Future<int> countBlocked() async =>
      Sqflite.firstIntValue(await _db.rawQuery(
        'SELECT COUNT(*) FROM outbox WHERE attempts >= ?',
        [maxAttempts],
      )) ??
      0;

  /// Supprime de la file les opérations confirmées par le serveur ; compte un
  /// échec pour les autres. On supprime par id de ligne (pas par entité) : si
  /// l'utilisateur a modifié l'entité pendant l'envoi, sa nouvelle opération
  /// (autre id) reste en attente.
  Future<void> applyPushResult(
    List<OutboxOp> batch,
    Set<String> acceptedEntityIds,
    Map<String, String> rejectionReasons,
  ) async {
    await _db.transaction((txn) async {
      for (final op in batch) {
        if (acceptedEntityIds.contains(op.entityId)) {
          await txn.delete('outbox', where: 'id = ?', whereArgs: [op.id]);
        } else {
          await txn.rawUpdate(
            'UPDATE outbox SET attempts = attempts + 1, last_error = ? WHERE id = ?',
            [rejectionReasons[op.entityId] ?? 'Non confirmé par le serveur', op.id],
          );
        }
      }
    });
  }

  Future<void> resetBlocked() async {
    await _db.update(
      'outbox',
      {'attempts': 0},
      where: 'attempts >= ?',
      whereArgs: [maxAttempts],
    );
  }
}
