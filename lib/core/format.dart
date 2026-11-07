String formatFcfa(int amount) {
  final negative = amount < 0;
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('\u00A0');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}$buffer\u00A0FCFA';
}

String formatCompact(int value) {
  if (value >= 1000000) return '${_trim(value / 1000000)}M';
  if (value >= 1000) return '${_trim(value / 1000)}k';
  return '$value';
}

String _trim(double x) {
  final s = x.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

String _two(int n) => n.toString().padLeft(2, '0');

String formatDateTime(DateTime dt) {
  final l = dt.toLocal();
  return '${_two(l.day)}/${_two(l.month)}/${l.year} ${_two(l.hour)}:${_two(l.minute)}';
}

const _weekdays = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

String weekdayShort(DateTime dt) => _weekdays[dt.weekday - 1];
