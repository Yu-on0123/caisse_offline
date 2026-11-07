import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config.dart';
import '../core/format.dart';
import '../core/settings_store.dart';
import '../core/web_link.dart';
import '../data/demo_data.dart';
import '../data/expense_repository.dart';
import '../data/product_repository.dart';
import '../data/sale_repository.dart';
import '../sync/sync_service.dart';
import 'login_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  Future<void> _seedDemo() async {
    final products = context.read<ProductRepository>();
    final sales = context.read<SaleRepository>();
    final expenses = context.read<ExpenseRepository>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    await DemoData.seed(products: products, sales: sales, expenses: expenses);
    if (mounted) setState(() => _busy = false);
    messenger.showSnackBar(
        const SnackBar(content: Text('Données de démonstration ajoutées.')));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final sync = context.watch<SyncService>();
    final textTheme = Theme.of(context).textTheme;
    final errorColor = Theme.of(context).colorScheme.error;
    final lastSync = settings.lastSyncAt;

    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Espace web Ma Caisse'),
              subtitle: const Text(
                'Créer un compte, consulter vos données et confirmer une connexion',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.open_in_new),
              onTap: () => openWebSpace(context),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('État de la synchronisation',
                      style: textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(sync.isOnline
                      ? 'Réseau : disponible'
                      : 'Réseau : hors ligne'),
                  Text('Opérations en attente : ${sync.pendingCount}'),
                  if (sync.blockedCount > 0)
                    Text(
                      '${sync.blockedCount} opération(s) refusée(s) par le serveur, '
                      'réessayées à la prochaine synchronisation manuelle.',
                      style: TextStyle(color: errorColor),
                    ),
                  Text(
                    'Dernière synchronisation : '
                    '${lastSync == null ? 'jamais' : formatDateTime(lastSync)}',
                  ),
                  if (sync.lastError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(sync.lastError!,
                          style: TextStyle(color: errorColor)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Compte', style: textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            "La synchronisation est facultative : sans compte, l'application "
            'fonctionne entièrement sur ce téléphone.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (settings.isLoggedIn) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_circle_outlined),
              title: Text(settings.email ?? 'Connecté'),
              subtitle: const Text('Connecté'),
            ),
            FilledButton.icon(
              onPressed:
                  sync.isSyncing ? null : () => sync.syncNow(manual: true),
              icon: const Icon(Icons.sync),
              label: Text(sync.isSyncing
                  ? 'Synchronisation…'
                  : 'Synchroniser maintenant'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => settings.clearSession(),
              icon: const Icon(Icons.logout),
              label: const Text('Se déconnecter'),
            ),
          ] else
            const LoginCard(),
          const SizedBox(height: 32),
          Text('Démonstration', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _seedDemo,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Ajouter des données de démo'),
          ),
        ],
      ),
    );
  }
}
