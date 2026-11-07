import 'dart:convert';

/// Une modification locale en attente d'envoi au serveur.
/// `payload` est un instantané complet de l'entité au moment de la modification.
class OutboxOp {
  const OutboxOp({
    required this.id,
    required this.entity,
    required this.entityId,
    required this.payload,
    required this.updatedAt,
    required this.attempts,
  });

  final int id;
  final String entity;
  final String entityId;
  final Map<String, dynamic> payload;
  final String updatedAt;
  final int attempts;

  factory OutboxOp.fromMap(Map<String, Object?> map) => OutboxOp(
        id: map['id'] as int,
        entity: map['entity'] as String,
        entityId: map['entity_id'] as String,
        payload: jsonDecode(map['payload'] as String) as Map<String, dynamic>,
        updatedAt: map['updated_at'] as String,
        attempts: map['attempts'] as int,
      );

  Map<String, Object?> toApi() => {
        'entity': entity,
        'id': entityId,
        'updated_at': updatedAt,
        'data': payload,
      };
}
