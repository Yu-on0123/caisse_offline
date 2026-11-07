import 'package:flutter/foundation.dart';

/// Configuration fixée à la compilation (jamais saisie par l'utilisateur).
///
///   flutter run --dart-define-from-file=env.json
///   flutter build apk --release --dart-define-from-file=env.json
///
/// avec un fichier env.json du type :
///   { "API_URL": "https://caisse.exemple.com", "WEB_URL": "https://caisse.exemple.com" }
class AppConfig {
  static const String _apiUrl = String.fromEnvironment('API_URL');
  static const String _webUrl = String.fromEnvironment('WEB_URL');

  /// Adresse du serveur, sans « /api » (ajouté automatiquement).
  /// Valeurs par défaut de développement si API_URL n'est pas fourni :
  ///  - navigateur / ordinateur : http://127.0.0.1:8000
  ///  - émulateur Android : http://10.0.2.2:8000 (= le PC qui héberge l'émulateur)
  static String get serverRoot {
    if (_apiUrl.trim().isNotEmpty) return normalizeRoot(_apiUrl);
    return kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';
  }

  /// Base de toutes les routes de l'API.
  static String get apiBase => '$serverRoot/api';

  /// Adresse de l'espace web (création de compte, consultation des données,
  /// affichage du code de confirmation). Par défaut, la racine du serveur.
  static String get webUrl {
    if (_webUrl.trim().isNotEmpty) return normalizeWebUrl(_webUrl);
    return serverRoot;
  }

  /// Nom de l'appareil transmis au serveur : il apparaît dans l'alerte de connexion
  /// et dans la liste des appareils de l'espace web.
  static String get deviceLabel =>
      kIsWeb ? 'Ma Caisse (navigateur)' : 'Ma Caisse (${defaultTargetPlatform.name})';

  /// Retire les « / » finaux et un éventuel « /api » ajouté par erreur.
  static String normalizeRoot(String value) {
    var root = value.trim().replaceAll(RegExp(r'/+$'), '');
    if (root.endsWith('/api')) {
      root = root.substring(0, root.length - 4);
    }
    return root;
  }

  /// Retire les espaces et les « / » finaux d'une adresse web.
  static String normalizeWebUrl(String value) =>
      value.trim().replaceAll(RegExp(r'/+$'), '');
}
