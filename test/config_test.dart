import 'package:caisse_offline/core/config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig.normalizeRoot', () {
    test('retire les / finaux', () {
      expect(AppConfig.normalizeRoot('http://serveur:8000/'), 'http://serveur:8000');
    });
    test('retire un /api ajouté par erreur', () {
      expect(AppConfig.normalizeRoot('http://serveur:8000/api'), 'http://serveur:8000');
      expect(AppConfig.normalizeRoot('https://caisse.exemple.com/api/'), 'https://caisse.exemple.com');
    });
    test('espaces autour de la valeur ignorés', () {
      expect(AppConfig.normalizeRoot('  http://serveur:8000  '), 'http://serveur:8000');
    });
  });

  group('AppConfig.normalizeWebUrl', () {
    test('retire les espaces et les / finaux', () {
      expect(AppConfig.normalizeWebUrl(' https://caisse.exemple.com/ '), 'https://caisse.exemple.com');
    });
    test('conserve un chemin éventuel', () {
      expect(AppConfig.normalizeWebUrl('https://exemple.com/caisse/'), 'https://exemple.com/caisse');
    });
  });

  test('apiBase se termine par /api', () {
    expect(AppConfig.apiBase.endsWith('/api'), isTrue);
  });

  test('l’espace web a une adresse par défaut', () {
    expect(AppConfig.webUrl, isNotEmpty);
  });

  test('le nom de l’appareil est renseigné', () {
    expect(AppConfig.deviceLabel, startsWith('Ma Caisse'));
  });
}
