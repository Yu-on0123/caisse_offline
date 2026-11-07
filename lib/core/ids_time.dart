import 'package:uuid/uuid.dart';

final Uuid _uuid = Uuid();

/// Identifiant généré côté client (UUID v4) : indispensable pour créer des
/// données hors ligne sans risque de collision avec le serveur.
String newId() => _uuid.v4();

/// Sérialise une date en ISO 8601 UTC avec une précision fixe (millisecondes).
/// Un format constant permet de comparer deux dates comme du texte en SQL.
String toIso(DateTime dt) => DateTime.fromMillisecondsSinceEpoch(
      dt.millisecondsSinceEpoch,
      isUtc: true,
    ).toIso8601String();

String nowIso() => toIso(DateTime.now());

/// Normalise une date reçue (du serveur par exemple) vers notre format.
String? normalizeIso(Object? value) {
  if (value == null) return null;
  final text = value.toString();
  if (text.isEmpty) return null;
  return toIso(DateTime.parse(text));
}

DateTime parseLocal(String iso) => DateTime.parse(iso).toLocal();
