/// Every rule the app enforces, as pure functions over a list of entries.
/// No Flutter, no Firebase — this is the part worth unit-testing, and the
/// part worth talking about in the presentation.
library;

import '../models/app_settings.dart';
import '../models/entry.dart';
// `intl` is a pure Dart package, so alert text can be formatted the same way
// as the rest of the UI without dragging Flutter into this layer.
import 'format.dart';

// ---------------------------------------------------------------------------
// month keys
// ---------------------------------------------------------------------------

String monthKeyOf(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

String thisMonth() => monthKeyOf(DateTime.now());

String shiftMonth(String key, int delta) {
  final parts = key.split('-');
  final d = DateTime(int.parse(parts[0]), int.parse(parts[1]) + delta, 1);
  return monthKeyOf(d);
}

/// Whole months from [from] up to and including [to].
int monthsBetween(String from, String to) {
  final f = from.split('-').map(int.parse).toList();
  final t = to.split('-').map(int.parse).toList();
  return (t[0] - f[0]) * 12 + (t[1] - f[1]);
}

Iterable<Entry> _live(List<Entry> entries) => entries.where((e) => !e.deleted);

// ---------------------------------------------------------------------------
// balances
// ---------------------------------------------------------------------------

/// What is sitting in a pot: everything that arrived, less everything that left.
int potBalance(List<Entry> entries, Ref pot) {
  var total = 0;
  for (final e in _live(entries)) {
    if (e.to == pot) total += e.amount;
    if (e.from == pot) total -= e.amount;
  }
  return total;
}

int bankBalance(List<Entry> entries) => potBalance(entries, Ref.bank);

int savingsBalance(List<Entry> entries) => potBalance(entries, Ref.savings);

// ---------------------------------------------------------------------------
// monthly rollup
// ---------------------------------------------------------------------------

class MonthStats {
  const MonthStats({
    required this.key,
    this.moneyIn = 0,
    this.moneyOut = 0,
    this.savedIn = 0,
    this.savedOut = 0,
    this.count = 0,
    this.bySource = const {},
  });

  final String key;
  final int moneyIn;
  final int moneyOut;
  final int savedIn;
  final int savedOut;
  final int count;
  final Map<Source, int> bySource;

  /// The number that matters: how much the stash grew this month.
  int get netSaved => savedIn - savedOut;
}

MonthStats statsFor(List<Entry> entries, String key) {
  var moneyIn = 0, moneyOut = 0, savedIn = 0, savedOut = 0, count = 0;
  final bySource = <Source, int>{};

  for (final e in _live(entries)) {
    if (e.monthKey != key) continue;
    count++;
    if (e.from.isOutside) {
      moneyIn += e.amount;
      bySource[e.source] = (bySource[e.source] ?? 0) + e.amount;
    }
    if (e.to.isOutside) moneyOut += e.amount;
    if (e.to == Ref.savings) savedIn += e.amount;
    if (e.from == Ref.savings) savedOut += e.amount;
  }

  return MonthStats(
    key: key,
    moneyIn: moneyIn,
    moneyOut: moneyOut,
    savedIn: savedIn,
    savedOut: savedOut,
    count: count,
    bySource: bySource,
  );
}

/// Every month with activity, plus the current one, newest first.
List<String> activeMonths(List<Entry> entries) {
  final keys = _live(entries).map((e) => e.monthKey).toSet()..add(thisMonth());
  final sorted = keys.toList()..sort();
  return sorted.reversed.toList();
}

// ---------------------------------------------------------------------------
// goal progress
// ---------------------------------------------------------------------------

class Progress {
  const Progress({
    required this.saved,
    required this.goal,
    required this.fraction,
    required this.monthsElapsed,
    required this.expectedByNow,
    required this.aheadBy,
    required this.remainingMonths,
    required this.neededPerRemainingMonth,
  });

  final int saved;
  final int goal;
  final double fraction;
  final int monthsElapsed;
  final int expectedByNow;
  final int aheadBy;
  final int remainingMonths;
  final int neededPerRemainingMonth;

  bool get onTrack => aheadBy >= 0;
}

Progress computeProgress(List<Entry> entries, AppSettings settings) {
  final saved = savingsBalance(entries);
  final goal = settings.goal;
  final elapsed = monthsBetween(settings.effectiveStartMonth, thisMonth()) + 1;
  final clamped = elapsed.clamp(0, settings.goalMonths);

  // Pace is judged on *finished* months only — being halfway through the
  // current month should not read as falling behind.
  final expectedByNow = settings.monthlyTarget * (clamped - 1).clamp(0, settings.goalMonths);
  // ...and the current month still counts toward what is left to save.
  final remainingMonths = (settings.goalMonths - clamped + 1).clamp(0, settings.goalMonths);
  final shortfall = (goal - saved).clamp(0, goal);

  return Progress(
    saved: saved,
    goal: goal,
    fraction: goal > 0 ? (saved / goal).clamp(0.0, 1.0) : 0,
    monthsElapsed: clamped,
    expectedByNow: expectedByNow,
    aheadBy: saved - expectedByNow,
    remainingMonths: remainingMonths,
    neededPerRemainingMonth:
        remainingMonths > 0 ? (shortfall / remainingMonths).ceil() : shortfall,
  );
}

// ---------------------------------------------------------------------------
// alerts — the reason the app exists
// ---------------------------------------------------------------------------

enum AlertLevel { danger, warning, good, info }

class LedgerAlert {
  const LedgerAlert({
    required this.id,
    required this.level,
    required this.title,
    required this.detail,
    this.opensAdd = false,
  });

  final String id;
  final AlertLevel level;
  final String title;
  final String detail;
  final bool opensAdd;

  bool get needsAttention =>
      level == AlertLevel.danger || level == AlertLevel.warning;
}

/// Say something, unprompted, when a month is heading the wrong way —
/// without nagging about five things at once.
List<LedgerAlert> computeAlerts(
  List<Entry> entries,
  AppSettings settings, {
  DateTime? today,
}) {
  final now = today ?? DateTime.now();
  final cur = monthKeyOf(now);
  final current = statsFor(entries, cur);
  final previous = statsFor(entries, shiftMonth(cur, -1));
  final day = now.day;
  final out = <LedgerAlert>[];

  if (_live(entries).isEmpty) {
    return const [
      LedgerAlert(
        id: 'get-started',
        level: AlertLevel.info,
        title: 'Start with what is in your account today',
        detail: 'Log a starting bank balance, then everything else follows on.',
        opensAdd: true,
      ),
    ];
  }

  if (current.savedOut > 0) {
    out.add(LedgerAlert(
      id: 'dipped',
      level: AlertLevel.danger,
      title: 'You took ${yen(current.savedOut)} out of savings this month',
      detail: 'Put it back before the month ends if you can.',
      opensAdd: true,
    ));
  }

  final hadLastMonth = previous.count > 0;
  if (hadLastMonth && current.netSaved < previous.netSaved) {
    final gap = previous.netSaved - current.netSaved;
    if (current.count == 0) {
      out.add(LedgerAlert(
        id: 'nothing-yet',
        level: day >= 15 ? AlertLevel.warning : AlertLevel.info,
        title: 'Nothing logged yet this month',
        detail: 'Last month you saved ${yen(previous.netSaved)}. '
            'Log the scholarship to stay level.',
        opensAdd: true,
      ));
    } else {
      out.add(LedgerAlert(
        id: 'below-last-month',
        level: AlertLevel.warning,
        title: '${yen(gap)} behind last month',
        detail: 'This month ${yen(current.netSaved)}, last month ${yen(previous.netSaved)}.',
      ));
    }
  }

  if (day >= 25 && current.savedIn == 0) {
    out.add(const LedgerAlert(
      id: 'month-ending',
      level: AlertLevel.warning,
      title: 'Month is nearly over and nothing has gone into savings',
      detail: 'Log it now so the streak holds.',
      opensAdd: true,
    ));
  }

  if (current.netSaved > 0 && current.netSaved < settings.monthlyTarget) {
    out.add(LedgerAlert(
      id: 'below-target',
      level: AlertLevel.info,
      title: '${yen(settings.monthlyTarget - current.netSaved)} short of your target',
      detail: 'Still time this month.',
    ));
  }

  if (out.isEmpty && current.netSaved >= settings.monthlyTarget) {
    out.add(LedgerAlert(
      id: 'on-track',
      level: AlertLevel.good,
      title: 'Target hit — ${yen(current.netSaved)} saved this month',
      detail: hadLastMonth && current.netSaved > previous.netSaved
          ? '${yen(current.netSaved - previous.netSaved)} more than last month.'
          : 'Keep it going.',
    ));
  }

  // Three is the most anyone reads before it becomes wallpaper.
  out.sort((a, b) => a.level.index.compareTo(b.level.index));
  return out.take(3).toList();
}
