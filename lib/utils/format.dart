import 'package:intl/intl.dart';

/// Locale-aware formatting via the `intl` package (Lecture 06).
/// Yen has no minor units, so decimals are switched off everywhere.
final NumberFormat _yen = NumberFormat.currency(
  locale: 'ja_JP',
  symbol: '¥',
  decimalDigits: 0,
);

final NumberFormat _plain = NumberFormat.decimalPattern('ja_JP');

String yen(num value) => _yen.format(value.round());

String plain(num value) => _plain.format(value.round());

/// "+¥1,200" / "−¥1,200" — the sign carries meaning, so it is explicit.
String signedYen(num value) {
  if (value == 0) return yen(0);
  final sign = value > 0 ? '+' : '−';
  return '$sign${yen(value.abs())}';
}

String monthLabel(String monthKey) {
  final parts = monthKey.split('-');
  final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
  return DateFormat.yMMM().format(date);
}

String dayLabel(DateTime date) => DateFormat.yMMMd().format(date);

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
