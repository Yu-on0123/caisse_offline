import 'package:sqflite/sqflite.dart';

import '../core/ids_time.dart';

enum StatsPeriod { day, week, month }

class PeriodStats {
  const PeriodStats({
    required this.sales,
    required this.expenses,
    required this.salesCount,
  });

  final int sales;
  final int expenses;
  final int salesCount;

  int get profit => sales - expenses;
}

class DayTotal {
  const DayTotal(this.day, this.total);

  final DateTime day;
  final int total;
}

class DashboardData {
  const DashboardData({required this.stats, required this.lastDays});

  final PeriodStats stats;
  final List<DayTotal> lastDays;
}

class StatsRepository {
  StatsRepository(this._db);

  final Database _db;

  Future<DashboardData> dashboard(StatsPeriod period) async {
    final now = DateTime.now();
    final range = _range(period, now);
    final from = toIso(range[0]);
    final to = toIso(range[1]);

    final salesRow = (await _db.rawQuery(
      'SELECT COALESCE(SUM(total), 0) AS s, COUNT(*) AS c FROM sales '
      'WHERE deleted_at IS NULL AND sold_at >= ? AND sold_at < ?',
      [from, to],
    ))
        .first;
    final expensesRow = (await _db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS s FROM expenses '
      'WHERE deleted_at IS NULL AND spent_at >= ? AND spent_at < ?',
      [from, to],
    ))
        .first;

    return DashboardData(
      stats: PeriodStats(
        sales: (salesRow['s'] as num).toInt(),
        expenses: (expensesRow['s'] as num).toInt(),
        salesCount: (salesRow['c'] as num).toInt(),
      ),
      lastDays: await _lastSevenDays(now),
    );
  }

  List<DateTime> _range(StatsPeriod period, DateTime now) {
    switch (period) {
      case StatsPeriod.day:
        return [
          DateTime(now.year, now.month, now.day),
          DateTime(now.year, now.month, now.day + 1),
        ];
      case StatsPeriod.week:
        {
          final start = DateTime(now.year, now.month, now.day - (now.weekday - 1));
          return [start, DateTime(start.year, start.month, start.day + 7)];
        }
      case StatsPeriod.month:
        return [
          DateTime(now.year, now.month, 1),
          DateTime(now.year, now.month + 1, 1),
        ];
    }
  }

  Future<List<DayTotal>> _lastSevenDays(DateTime now) async {
    final first = DateTime(now.year, now.month, now.day - 6);
    final end = DateTime(now.year, now.month, now.day + 1);
    final rows = await _db.rawQuery(
      'SELECT sold_at, total FROM sales '
      'WHERE deleted_at IS NULL AND sold_at >= ? AND sold_at < ?',
      [toIso(first), toIso(end)],
    );
    final totals = <DateTime, int>{};
    for (final row in rows) {
      final d = DateTime.parse(row['sold_at'] as String).toLocal();
      final key = DateTime(d.year, d.month, d.day);
      totals[key] = (totals[key] ?? 0) + (row['total'] as int);
    }
    final days = [
      for (var i = 0; i < 7; i++) DateTime(first.year, first.month, first.day + i),
    ];
    return [for (final day in days) DayTotal(day, totals[day] ?? 0)];
  }
}
