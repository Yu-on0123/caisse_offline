import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../core/data_events.dart';
import '../core/settings_store.dart';
import '../data/outbox_repository.dart';
import 'api_client.dart';
import 'change_applier.dart';

/// Orchestre la synchronisation : push de l'outbox puis pull des changements.
///
/// Déclencheurs : retour du réseau, 2 s après une écriture locale, toutes les
/// 2 minutes, et bouton manuel. L'app ne dépend jamais du résultat : toute
/// la lecture/écriture passe par SQLite.
class SyncService extends ChangeNotifier {
  SyncService({
    required OutboxRepository outbox,
    required SettingsStore settings,
    required ApiClient api,
    required ChangeApplier applier,
    required DataEvents events,
  })  : _outbox = outbox,
        _settings = settings,
        _api = api,
        _applier = applier,
        _events = events;

  final OutboxRepository _outbox;
  final SettingsStore _settings;
  final ApiClient _api;
  final ChangeApplier _applier;
  final DataEvents _events;

  bool _syncing = false;
  bool _online = true;
  String? _lastError;
  int _pending = 0;
  int _blocked = 0;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _timer;
  Timer? _debounce;

  bool get isSyncing => _syncing;
  bool get isOnline => _online;
  String? get lastError => _lastError;
  int get pendingCount => _pending;
  int get blockedCount => _blocked;

  static bool _hasNetwork(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  Future<void> start() async {
    await refreshCounts();
    _online = _hasNetwork(await Connectivity().checkConnectivity());
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final wasOnline = _online;
      _online = _hasNetwork(results);
      notifyListeners();
      if (_online && !wasOnline) unawaited(syncNow());
    });
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => unawaited(syncNow()));
    unawaited(syncNow());
  }

  Future<void> refreshCounts() async {
    _pending = await _outbox.countPending();
    _blocked = await _outbox.countBlocked();
    notifyListeners();
  }

  /// Appelé après chaque écriture locale.
  void onLocalChange() {
    unawaited(refreshCounts());
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () => unawaited(syncNow()));
  }

  Future<void> syncNow({bool manual = false}) async {
    if (_syncing || !_settings.canSync) return;
    if (!_online && !manual) return;

    _syncing = true;
    _lastError = null;
    notifyListeners();
    try {
      if (manual) await _outbox.resetBlocked();
      await _push();
      await _pull();
      await _settings.markSynced();
    } on ApiAuthException catch (e) {
      await _settings.clearSession();
      _lastError = e.message;
    } catch (e) {
      _lastError = describeSyncError(e);
    } finally {
      _syncing = false;
      await refreshCounts();
    }
  }

  Future<void> _push() async {
    while (true) {
      final batch = await _outbox.pending(limit: 50);
      if (batch.isEmpty) return;

      final result = await _api.push([for (final op in batch) op.toApi()]);
      final accepted = result.accepted.toSet();
      final reasons = {for (final r in result.rejected) r.id: r.reason};

      await _outbox.applyPushResult(batch, accepted, reasons);

      // Aucun progrès : on s'arrête, les échecs seront comptés puis bloqués.
      if (!batch.any((op) => accepted.contains(op.entityId))) return;
    }
  }

  Future<void> _pull() async {
    var since = _settings.syncCursor;
    var anyChange = false;
    while (true) {
      final result = await _api.pull(since);
      if (await _applier.apply(result.changes)) anyChange = true;
      since = result.cursor;
      await _settings.setSyncCursor(since);
      if (!result.hasMore) break;
    }
    if (anyChange) _events.changed();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _timer?.cancel();
    _debounce?.cancel();
    super.dispose();
  }
}
