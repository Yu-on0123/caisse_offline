/// Règle de résolution de conflit : « la dernière écriture gagne ».
class SyncMerge {
  /// Faut-il appliquer la version distante par-dessus la version locale ?
  /// Oui si elle n'est pas plus ancienne. À égalité on applique : les données
  /// sont identiques (c'est typiquement l'écho de notre propre envoi).
  static bool shouldApplyRemote({
    required String? localUpdatedAt,
    required String remoteUpdatedAt,
  }) {
    if (localUpdatedAt == null) return true;
    return !DateTime.parse(localUpdatedAt).isAfter(DateTime.parse(remoteUpdatedAt));
  }
}
