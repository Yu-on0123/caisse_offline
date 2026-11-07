import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../data/models/product.dart';
import '../data/models/sale.dart';
import '../data/product_repository.dart';
import '../data/sale_repository.dart';
import 'common.dart';
import 'live_query.dart';

class NewSaleScreen extends StatefulWidget {
  const NewSaleScreen({super.key});

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  final List<CartLine> _cart = [];
  bool _saving = false;

  int get _total => _cart.fold<int>(0, (sum, line) => sum + line.total);

  int _quantityOf(Product product) {
    for (final line in _cart) {
      if (line.productId == product.id) return line.quantity;
    }
    return 0;
  }

  void _add(Product product) {
    final index = _cart.indexWhere((l) => l.productId == product.id);
    setState(() {
      if (index == -1) {
        _cart.add(CartLine(productId: product.id, name: product.name, unitPrice: product.price));
      } else {
        _cart[index].quantity++;
      }
    });
  }

  void _remove(Product product) {
    final index = _cart.indexWhere((l) => l.productId == product.id);
    if (index == -1) return;
    setState(() {
      if (_cart[index].quantity > 1) {
        _cart[index].quantity--;
      } else {
        _cart.removeAt(index);
      }
    });
  }

  Future<void> _addFreeAmount() async {
    final amount = await askAmount(context, title: 'Montant libre');
    if (amount == null || !mounted) return;
    setState(() => _cart.add(CartLine(name: 'Vente libre', unitPrice: amount)));
  }

  Future<void> _submit() async {
    final repo = context.read<SaleRepository>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    final sale = await repo.create(lines: _cart);
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text('Vente enregistrée : ${formatFcfa(sale.total)}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = context.read<ProductRepository>();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle vente'),
        actions: [
          TextButton.icon(
            onPressed: _addFreeAmount,
            icon: const Icon(Icons.edit_note),
            label: const Text('Montant libre'),
          ),
        ],
      ),
      body: LiveQuery<List<Product>>(
        load: () => products.all(),
        builder: (context, items) {
          final freeLines = _cart.where((l) => l.productId == null).toList();
          return ListView(
            children: [
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Aucun produit enregistré. Ajoutez-en dans l’onglet Produits, '
                    'ou utilisez « Montant libre ».',
                  ),
                ),
              for (final product in items)
                ListTile(
                  title: Text(product.name),
                  subtitle: Text(formatFcfa(product.price)),
                  onTap: () => _add(product),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_quantityOf(product) > 0) ...[
                        IconButton(
                          tooltip: 'Retirer un',
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => _remove(product),
                        ),
                        Text('${_quantityOf(product)}', style: textTheme.titleMedium),
                      ],
                      IconButton(
                        tooltip: 'Ajouter un',
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => _add(product),
                      ),
                    ],
                  ),
                ),
              if (freeLines.isNotEmpty) ...[
                const Divider(),
                for (final line in freeLines)
                  ListTile(
                    leading: const Icon(Icons.edit_note),
                    title: const Text('Vente libre'),
                    subtitle: Text(formatFcfa(line.unitPrice)),
                    trailing: IconButton(
                      tooltip: 'Retirer',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _cart.remove(line)),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total', style: textTheme.bodySmall),
                    Text(
                      formatFcfa(_total),
                      style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: (_cart.isEmpty || _saving) ? null : _submit,
                icon: const Icon(Icons.check),
                label: const Text('Encaisser'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
