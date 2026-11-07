import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../data/models/product.dart';
import '../data/product_repository.dart';
import 'common.dart';
import 'live_query.dart';

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  Future<void> _add(BuildContext context, ProductRepository repo) async {
    final draft = await showDialog<_ProductDraft>(
      context: context,
      builder: (_) => const _ProductDialog(),
    );
    if (draft != null) await repo.create(name: draft.name, price: draft.price);
  }

  Future<void> _edit(BuildContext context, ProductRepository repo, Product product) async {
    final draft = await showDialog<_ProductDraft>(
      context: context,
      builder: (_) => _ProductDialog(initial: product),
    );
    if (draft != null) await repo.update(product, name: draft.name, price: draft.price);
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ProductRepository>();
    return Scaffold(
      body: LiveQuery<List<Product>>(
        load: () => repo.all(),
        builder: (context, products) {
          if (products.isEmpty) {
            return const EmptyState(
              icon: Icons.inventory_2_outlined,
              message: 'Aucun produit.\nAjoutez vos articles avec leur prix pour vendre en deux appuis.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: products.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final product = products[index];
              return ListTile(
                title: Text(product.name),
                subtitle: Text(formatFcfa(product.price)),
                onTap: () => _edit(context, repo, product),
                trailing: IconButton(
                  tooltip: 'Supprimer',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await confirmDelete(context, 'Supprimer « ${product.name} » ?')) {
                      await repo.delete(product);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-products',
        onPressed: () => _add(context, repo),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau produit'),
      ),
    );
  }
}

class _ProductDraft {
  const _ProductDraft(this.name, this.price);

  final String name;
  final int price;
}

class _ProductDialog extends StatefulWidget {
  const _ProductDialog({this.initial});

  final Product? initial;

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initial?.name ?? '');
  late final TextEditingController _price =
      TextEditingController(text: widget.initial?.price.toString() ?? '');

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final price = int.tryParse(_price.text.trim());
    if (name.isEmpty || price == null || price <= 0) return;
    Navigator.pop(context, _ProductDraft(name, price));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Nouveau produit' : 'Modifier le produit'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nom'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _price,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(9),
            ],
            decoration: const InputDecoration(labelText: 'Prix (FCFA)'),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: _submit, child: const Text('Enregistrer')),
      ],
    );
  }
}
