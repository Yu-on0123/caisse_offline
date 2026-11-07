import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/ids_time.dart';
import '../data/models/sale.dart';
import '../data/sale_repository.dart';
import 'common.dart';
import 'live_query.dart';
import 'new_sale_screen.dart';

class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<SaleRepository>();
    return Scaffold(
      body: LiveQuery<List<Sale>>(
        load: () => repo.recent(),
        builder: (context, sales) {
          if (sales.isEmpty) {
            return const EmptyState(
              icon: Icons.point_of_sale,
              message: 'Aucune vente pour le moment.\nAppuyez sur « Nouvelle vente » pour commencer.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: sales.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final sale = sales[index];
              return ListTile(
                isThreeLine: true,
                title: Text(
                  formatFcfa(sale.total),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${sale.summary}\n${formatDateTime(parseLocal(sale.soldAt))}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: 'Supprimer',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await confirmDelete(context, 'Supprimer cette vente ?')) {
                      await repo.delete(sale);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-sales',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const NewSaleScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle vente'),
      ),
    );
  }
}
