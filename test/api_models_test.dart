import 'package:caisse_offline/sync/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoginChallenge', () {
    test('lit la réponse du serveur', () {
      final challenge = LoginChallenge.fromJson({
        'challenge_id': '6f1c0a8e-0000-4000-8000-000000000001',
        'expires_at': '2026-10-20T10:25:00+00:00',
        'expires_in': 600,
        'code_length': 6,
        'message': 'Ouvrez votre espace web.',
      });

      expect(challenge.id, '6f1c0a8e-0000-4000-8000-000000000001');
      expect(challenge.expiresAt.toUtc(), DateTime.utc(2026, 10, 20, 10, 25));
      expect(challenge.message, 'Ouvrez votre espace web.');
    });

    test('le message est facultatif', () {
      final challenge = LoginChallenge.fromJson({
        'challenge_id': 'abc',
        'expires_at': '2026-10-20T10:25:00+00:00',
      });

      expect(challenge.message, isEmpty);
    });
  });

  group('describeSyncError', () {
    test('reprend le message explicite du serveur', () {
      final error = ApiException('Code incorrect (4 essais restants).', statusCode: 422, code: 'invalid_code');

      expect(describeSyncError(error), 'Code incorrect (4 essais restants).');
      expect(error.code, 'invalid_code');
    });

    test('explique une réponse illisible', () {
      expect(describeSyncError(const FormatException('x')), contains('réponse inattendue'));
    });
  });
}
