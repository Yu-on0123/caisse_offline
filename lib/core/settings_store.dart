import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Réglages persistants : session, curseur de synchronisation, dernière synchronisation.
/// L'adresse du serveur n'est pas stockée ici : elle est fixée à la compilation (AppConfig).
class SettingsStore extends ChangeNotifier {
  SettingsStore._(this._prefs);

  final SharedPreferences _prefs;

  static Future<SettingsStore> load() async =>
      SettingsStore._(await SharedPreferences.getInstance());

  static const _kToken = 'token';
  static const _kEmail = 'email';
  static const _kCursor = 'sync_cursor';
  static const _kLastSync = 'last_sync_ms';

  String? get token => _prefs.getString(_kToken);
  String? get email => _prefs.getString(_kEmail);
  String? get syncCursor => _prefs.getString(_kCursor);

  DateTime? get lastSyncAt {
    final ms = _prefs.getInt(_kLastSync);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  bool get isLoggedIn => (token ?? '').isNotEmpty;

  /// La synchronisation est optionnelle : sans compte connecté, l'application
  /// fonctionne en mode 100 % local.
  bool get canSync => isLoggedIn;

  Future<void> saveSession({required String token, required String email}) async {
    await _prefs.setString(_kToken, token);
    await _prefs.setString(_kEmail, email);
    // Un nouveau compte repart d'un historique de synchronisation vierge.
    await _prefs.remove(_kCursor);
    notifyListeners();
  }

  Future<void> clearSession() async {
    await _prefs.remove(_kToken);
    await _prefs.remove(_kEmail);
    await _prefs.remove(_kCursor);
    notifyListeners();
  }

  Future<void> setSyncCursor(String cursor) => _prefs.setString(_kCursor, cursor);

  Future<void> markSynced() async {
    await _prefs.setInt(_kLastSync, DateTime.now().millisecondsSinceEpoch);
    notifyListeners();
  }
}
