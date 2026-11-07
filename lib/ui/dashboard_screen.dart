import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../data/stats_repository.dart';
import 'live_query.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  StatsPeriod _period = StatsPeriod.day;

  @override
  Widget build(BuildContext context) {
    final stats = context.read<StatsRepository>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<StatsPeriod>(
          segments: const [
            ButtonSegment(value: StatsPeriod.day, label: Text("Aujourd'hui")),
            ButtonSegment(value: StatsPeriod.week, label: Text('Semaine')),
            ButtonSegment(value: StatsPeriod.month, label: Text('Mois')),
          ],
          selected: {_period},
          onSelectionChanged: (selection) => setState(() => _period = selection.first),
        ),
        const SizedBox(height: 16),
        LiveQuery<DashboardData>(
          reloadKey: _period,
          load: () => stats.dashboard(_period),
          builder: (context, data) => _DashboardContent(data: data),
        ),
      ],
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final stats = data.stats;
    final scheme = Theme.of(context).colorScheme;
    final profitColor = stats.profit >= 0 ? scheme.primary : scheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bénéfice estimé'),
                const SizedBox(height: 4),
                Text(
                  formatFcfa(stats.profit),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: profitColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ventes moins dépenses',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Ventes',
                value: formatFcfa(stats.sales),
                caption: '${stats.salesCount} vente(s)',
                icon: Icons.trending_up,
              ),
            ),
            Expanded(
              child: _StatCard(
                label: 'Dépenses',
                value: formatFcfa(stats.expenses),
                caption: ' ',
                icon: Icons.trending_down,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Ventes des 7 derniers jours', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        _WeekChart(days: data.lastDays),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, size: 18), const SizedBox(width: 6), Text(label)]),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(caption, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.days});

  final List<DayTotal> days;

  @override
  Widget build(BuildContext context) {
    final maxValue = days.fold<int>(0, (m, d) => d.total > m ? d.total : m);
    final color = Theme.of(context).colorScheme.primary;
    final small = Theme.of(context).textTheme.labelSmall;

    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in days)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(d.total == 0 ? '' : formatCompact(d.total), style: small),
                    const SizedBox(height: 4),
                    Container(
                      height: maxValue == 0 ? 2 : 100 * d.total / maxValue + 2,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(weekdayShort(d.day), style: small),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
