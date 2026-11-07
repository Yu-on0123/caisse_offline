import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/settings_store.dart';
import '../sync/sync_service.dart';

/// Indicateur d'état de synchronisation affiché dans la barre d'application.
class SyncBadge extends StatelessWidget {
  const SyncBadge({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    final settings = context.watch<SettingsStore>();

    final IconData icon;
    final String tooltip;
    if (!settings.canSync) {
      icon = Icons.cloud_off_outlined;
      tooltip = 'Mode local : synchronisation non configurée';
    } else if (sync.isSyncing) {
      icon = Icons.sync;
      tooltip = 'Synchronisation en cours…';
    } else if (!sync.isOnline) {
      icon = Icons.wifi_off;
      tooltip = 'Hors ligne : ${sync.pendingCount} opération(s) en attente';
    } else if (sync.lastError != null) {
      icon = Icons.error_outline;
      tooltip = sync.lastError!;
    } else if (sync.pendingCount > 0) {
      icon = Icons.cloud_upload_outlined;
      tooltip = '${sync.pendingCount} opération(s) en attente';
    } else {
      icon = Icons.cloud_done_outlined;
      tooltip = 'Tout est synchronisé';
    }

    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Badge(
        label: Text('${sync.pendingCount}'),
        isLabelVisible: sync.pendingCount > 0,
        child: Icon(icon),
      ),
    );
  }
}
