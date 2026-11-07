import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'app.dart';
import 'core/data_events.dart';
import 'core/settings_store.dart';
import 'data/app_database.dart';
import 'data/expense_repository.dart';
import 'data/outbox_repository.dart';
import 'data/product_repository.dart';
import 'data/sale_repository.dart';
import 'data/stats_repository.dart';
import 'sync/api_client.dart';
import 'sync/change_applier.dart';
import 'sync/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    // Factory web avec chemins absolus vers les binaires dans /web
    databaseFactory = createDatabaseFactoryFfiWeb(
      options: SqfliteFfiWebOptions(
        sharedWorkerUri: Uri.parse('/sqflite_sw.js'),
        sqlite3WasmUri: Uri.parse('/sqlite3.wasm'),
      ),
    );
  }

  // Tout démarre depuis SQLite : l'app n'a jamais besoin du réseau pour s'ouvrir.
  final db = await AppDatabase.open();
  final settings = await SettingsStore.load();
  final events = DataEvents();
  final outbox = OutboxRepository(db);
  final api = ApiClient(settings);
  final sync = SyncService(
    outbox: outbox,
    settings: settings,
    api: api,
    applier: ChangeApplier(db),
    events: events,
  );

  // Après chaque écriture locale : rafraîchir l'écran et planifier une synchro.
  void onWrite() {
    events.changed();
    sync.onLocalChange();
  }

  final products = ProductRepository(db, onWrite);
  final sales = SaleRepository(db, onWrite);
  final expenses = ExpenseRepository(db, onWrite);
  final stats = StatsRepository(db);

  await sync.start();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<DataEvents>.value(value: events),
        ChangeNotifierProvider<SettingsStore>.value(value: settings),
        ChangeNotifierProvider<SyncService>.value(value: sync),
        Provider<ApiClient>.value(value: api),
        Provider<ProductRepository>.value(value: products),
        Provider<SaleRepository>.value(value: sales),
        Provider<ExpenseRepository>.value(value: expenses),
        Provider<StatsRepository>.value(value: stats),
      ],
      child: const CaisseApp(),
    ),
  );
}