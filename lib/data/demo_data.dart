import 'dart:math';

import 'expense_repository.dart';
import 'models/expense.dart';
import 'models/product.dart';
import 'models/sale.dart';
import 'product_repository.dart';
import 'sale_repository.dart';

/// Jeu de données de démonstration (captures d'écran, GIF, démo recruteur).
class DemoData {
  static const _catalog = <String, int>{
    'Riz (1 kg)': 750,
    'Huile (1 L)': 1200,
    'Sucre (1 kg)': 800,
    'Savon': 300,
    'Sachet d’eau': 100,
    'Pain': 200,
  };

  static Future<void> seed({
    required ProductRepository products,
    required SaleRepository sales,
    required ExpenseRepository expenses,
  }) async {
    final random = Random(7);
    final created = <Product>[];
    for (final entry in _catalog.entries) {
      created.add(await products.create(name: entry.key, price: entry.value));
    }

    final now = DateTime.now();
    for (var daysAgo = 6; daysAgo >= 0; daysAgo--) {
      final count = 2 + random.nextInt(4);
      for (var i = 0; i < count; i++) {
        final shuffled = List<Product>.of(created)..shuffle(random);
        final lines = [
          for (final p in shuffled.take(1 + random.nextInt(3)))
            CartLine(
              productId: p.id,
              name: p.name,
              unitPrice: p.price,
              quantity: 1 + random.nextInt(4),
            ),
        ];
        final when = DateTime(
          now.year,
          now.month,
          now.day - daysAgo,
          8 + random.nextInt(10),
          random.nextInt(60),
        );
        if (when.isAfter(now)) continue;
        await sales.create(lines: lines, soldAt: when);
      }
      if (random.nextBool()) {
        await expenses.create(
          category: ExpenseCategories.all[random.nextInt(ExpenseCategories.all.length)],
          amount: (1 + random.nextInt(8)) * 500,
          spentAt: DateTime(now.year, now.month, now.day - daysAgo, 7, 30),
        );
      }
    }
  }
}
