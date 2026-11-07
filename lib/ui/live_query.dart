import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/data_events.dart';

/// Charge des données depuis SQLite et se recharge automatiquement chaque
/// fois que les données locales changent (écriture locale ou synchro).
class LiveQuery<T> extends StatefulWidget {
  const LiveQuery({
    super.key,
    required this.load,
    required this.builder,
    this.reloadKey,
  });

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data) builder;

  /// Si cette valeur change, la requête est relancée (ex. période choisie).
  final Object? reloadKey;

  @override
  State<LiveQuery<T>> createState() => _LiveQueryState<T>();
}

class _LiveQueryState<T> extends State<LiveQuery<T>> {
  late final DataEvents _events;
  T? _data;
  Object? _error;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _events = context.read<DataEvents>();
    _events.addListener(_reload);
    _reload();
  }

  @override
  void didUpdateWidget(covariant LiveQuery<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadKey != widget.reloadKey) _reload();
  }

  @override
  void dispose() {
    _events.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final data = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
        _loaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Erreur : $_error')));
    }
    return widget.builder(context, _data as T);
  }
}
