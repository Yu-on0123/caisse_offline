import 'package:caisse_offline/core/format.dart';
import 'package:caisse_offline/core/ids_time.dart';
import 'package:caisse_offline/data/models/sale.dart';
import 'package:caisse_offline/sync/sync_merge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatFcfa', () {
    test('groupe les milliers', () {
      expect(formatFcfa(1250000), '1\u00A0250\u00A0000\u00A0FCFA');
    });
    test('petit montant', () {
      expect(formatFcfa(500), '500\u00A0FCFA');
    });
    test('montant négatif', () {
      expect(formatFcfa(-1500), '-1\u00A0500\u00A0FCFA');
    });
  });

  group('dates', () {
    test('format ISO à précision fixe (comparable comme du texte)', () {
      expect(toIso(DateTime.utc(2026, 1, 1)), '2026-01-01T00:00:00.000Z');
    });
    test('normalise un format serveur à 6 décimales', () {
      expect(normalizeIso('2026-10-17T10:15:30.000000Z'), '2026-10-17T10:15:30.000Z');
    });
  });

  group('SyncMerge (la dernière écriture gagne)', () {
    const older = '2026-10-17T10:00:00.000Z';
    const newer = '2026-10-17T11:00:00.000Z';

    test('applique si rien en local', () {
      expect(SyncMerge.shouldApplyRemote(localUpdatedAt: null, remoteUpdatedAt: older), isTrue);
    });
    test('applique si le distant est plus récent', () {
      expect(SyncMerge.shouldApplyRemote(localUpdatedAt: older, remoteUpdatedAt: newer), isTrue);
    });
    test('ignore si le local est plus récent', () {
      expect(SyncMerge.shouldApplyRemote(localUpdatedAt: newer, remoteUpdatedAt: older), isFalse);
    });
    test('applique à égalité (écho de notre propre envoi)', () {
      expect(SyncMerge.shouldApplyRemote(localUpdatedAt: newer, remoteUpdatedAt: newer), isTrue);
    });
  });

  group('Sale', () {
    const items = [
      SaleItem(id: 'i1', saleId: 's1', productName: 'Savon', unitPrice: 300, quantity: 2),
      SaleItem(id: 'i2', saleId: 's1', productName: 'Riz', unitPrice: 750, quantity: 1),
    ];

    test('résumé lisible', () {
      const sale = Sale(
        id: 's1',
        total: 1350,
        soldAt: '2026-10-17T10:00:00.000Z',
        createdAt: '2026-10-17T10:00:00.000Z',
        updatedAt: '2026-10-17T10:00:00.000Z',
        items: items,
      );
      expect(sale.summary, '2× Savon, 1× Riz');
    });

    test('aller-retour JSON conserve la vente et ses articles', () {
      const sale = Sale(
        id: 's1',
        total: 1350,
        soldAt: '2026-10-17T10:00:00.000Z',
        createdAt: '2026-10-17T10:00:00.000Z',
        updatedAt: '2026-10-17T10:00:00.000Z',
        items: items,
      );
      final copy = Sale.fromJson(sale.toJson());
      expect(copy.id, sale.id);
      expect(copy.total, 1350);
      expect(copy.items.length, 2);
      expect(copy.items.first.saleId, 's1');
    });
  });
}
