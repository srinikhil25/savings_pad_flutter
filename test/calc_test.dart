import 'package:flutter_test/flutter_test.dart';
import 'package:savings_pad/models/app_settings.dart';
import 'package:savings_pad/models/entry.dart';
import 'package:savings_pad/utils/calc.dart';

/// The calculation layer is pure Dart, so it can be tested with no widgets,
/// no emulator and no Firebase connection. That separation is the practical
/// payoff of the MVC split.

Entry _entry({
  required String id,
  required String date,
  required int amount,
  required Ref from,
  required Ref to,
  bool deleted = false,
}) {
  return Entry(
    id: id,
    date: DateTime.parse(date),
    amount: amount,
    from: from,
    to: to,
    updatedAt: DateTime.parse('2026-08-01T00:00:00Z'),
    deleted: deleted,
  );
}

void main() {
  group('pot balances', () {
    test('money arriving from outside raises the bank balance', () {
      final entries = [
        _entry(id: '1', date: '2026-08-01', amount: 48000, from: Ref.outside, to: Ref.bank),
      ];
      expect(bankBalance(entries), 48000);
      expect(savingsBalance(entries), 0);
    });

    test('a transfer moves money without creating or destroying any', () {
      final entries = [
        _entry(id: '1', date: '2026-08-01', amount: 100000, from: Ref.outside, to: Ref.bank),
        _entry(id: '2', date: '2026-08-02', amount: 48000, from: Ref.bank, to: Ref.savings),
      ];
      expect(bankBalance(entries), 52000);
      expect(savingsBalance(entries), 48000);
      expect(bankBalance(entries) + savingsBalance(entries), 100000);
    });

    test('spending never touches the savings stash', () {
      final entries = [
        _entry(id: '1', date: '2026-08-01', amount: 100000, from: Ref.outside, to: Ref.bank),
        _entry(id: '2', date: '2026-08-02', amount: 48000, from: Ref.bank, to: Ref.savings),
        _entry(id: '3', date: '2026-08-03', amount: 30000, from: Ref.bank, to: Ref.outside),
      ];
      expect(savingsBalance(entries), 48000);
      expect(bankBalance(entries), 22000);
    });

    test('deleted entries are excluded', () {
      final entries = [
        _entry(id: '1', date: '2026-08-01', amount: 48000, from: Ref.outside, to: Ref.bank),
        _entry(
          id: '2',
          date: '2026-08-02',
          amount: 10000,
          from: Ref.outside,
          to: Ref.bank,
          deleted: true,
        ),
      ];
      expect(bankBalance(entries), 48000);
    });
  });

  group('monthly rollup', () {
    final entries = [
      _entry(id: '1', date: '2026-07-10', amount: 48000, from: Ref.outside, to: Ref.bank),
      _entry(id: '2', date: '2026-07-11', amount: 48000, from: Ref.bank, to: Ref.savings),
      _entry(id: '3', date: '2026-08-01', amount: 48000, from: Ref.outside, to: Ref.bank),
      _entry(id: '4', date: '2026-08-01', amount: 48000, from: Ref.bank, to: Ref.savings),
      _entry(id: '5', date: '2026-08-02', amount: 15000, from: Ref.savings, to: Ref.outside),
    ];

    test('nets savings in against savings out', () {
      final august = statsFor(entries, '2026-08');
      expect(august.savedIn, 48000);
      expect(august.savedOut, 15000);
      expect(august.netSaved, 33000);
    });

    test('a dip into savings makes the month worse than the one before', () {
      expect(statsFor(entries, '2026-07').netSaved, 48000);
      expect(statsFor(entries, '2026-08').netSaved, 33000);
    });
  });

  group('month arithmetic', () {
    test('shiftMonth rolls across the year boundary', () {
      expect(shiftMonth('2026-01', -1), '2025-12');
      expect(shiftMonth('2026-12', 1), '2027-01');
    });

    test('monthsBetween counts whole months', () {
      expect(monthsBetween('2026-05', '2026-08'), 3);
      expect(monthsBetween('2026-08', '2026-08'), 0);
    });
  });

  group('goal progress', () {
    const settings = AppSettings(
      monthlyTarget: 48000,
      goalMonths: 8,
      startMonth: '2026-08',
    );

    test('pace ignores the month still in progress', () {
      // Month 1 of the plan: nothing is overdue yet, so saving nothing is
      // "on pace" rather than "48,000 behind".
      final progress = computeProgress(const [], settings);
      expect(progress.monthsElapsed, 1);
      expect(progress.expectedByNow, 0);
      expect(progress.onTrack, isTrue);
    });

    test('the current month still counts toward the runway', () {
      final progress = computeProgress(const [], settings);
      expect(progress.remainingMonths, 8);
      expect(progress.neededPerRemainingMonth, 48000);
    });

    test('fraction never exceeds one even when over-saved', () {
      final entries = [
        _entry(id: '1', date: '2026-08-01', amount: 900000, from: Ref.bank, to: Ref.savings),
      ];
      expect(computeProgress(entries, settings).fraction, 1.0);
    });
  });

  group('alerts', () {
    const settings = AppSettings(monthlyTarget: 48000, goalMonths: 8, startMonth: '2026-07');

    test('an empty ledger asks for a starting balance', () {
      final alerts = computeAlerts(const [], settings);
      expect(alerts.single.id, 'get-started');
    });

    test('taking money out of savings raises a danger alert', () {
      final entries = [
        _entry(id: '1', date: '2026-08-01', amount: 48000, from: Ref.bank, to: Ref.savings),
        _entry(id: '2', date: '2026-08-02', amount: 15000, from: Ref.savings, to: Ref.outside),
      ];
      final alerts = computeAlerts(entries, settings, today: DateTime(2026, 8, 3));
      expect(alerts.first.level, AlertLevel.danger);
      expect(alerts.first.id, 'dipped');
    });

    test('falling below last month is flagged', () {
      final entries = [
        _entry(id: '1', date: '2026-07-10', amount: 48000, from: Ref.bank, to: Ref.savings),
        _entry(id: '2', date: '2026-08-01', amount: 20000, from: Ref.bank, to: Ref.savings),
      ];
      final alerts = computeAlerts(entries, settings, today: DateTime(2026, 8, 3));
      expect(alerts.any((a) => a.id == 'below-last-month'), isTrue);
    });

    test('never shows more than three alerts at once', () {
      final entries = [
        _entry(id: '1', date: '2026-07-10', amount: 48000, from: Ref.bank, to: Ref.savings),
        _entry(id: '2', date: '2026-08-01', amount: 1000, from: Ref.bank, to: Ref.savings),
        _entry(id: '3', date: '2026-08-02', amount: 500, from: Ref.savings, to: Ref.outside),
      ];
      final alerts = computeAlerts(entries, settings, today: DateTime(2026, 8, 27));
      expect(alerts.length, lessThanOrEqualTo(3));
    });

    test('hitting the target is celebrated when nothing is wrong', () {
      final entries = [
        _entry(id: '1', date: '2026-08-01', amount: 48000, from: Ref.bank, to: Ref.savings),
      ];
      final alerts = computeAlerts(entries, settings, today: DateTime(2026, 8, 3));
      expect(alerts.single.level, AlertLevel.good);
    });
  });

  group('serialisation', () {
    test('an entry survives a round trip through JSON', () {
      final original = _entry(
        id: 'abc',
        date: '2026-08-04',
        amount: 48000,
        from: Ref.bank,
        to: Ref.savings,
      );
      final restored = Entry.fromJson('abc', original.toJson());

      expect(restored.amount, original.amount);
      expect(restored.from, original.from);
      expect(restored.to, original.to);
      expect(restored.monthKey, '2026-08');
    });

    test('an unknown ref falls back to outside rather than throwing', () {
      expect(Ref.parse('pot:mattress'), Ref.outside);
      expect(Ref.parse(null), Ref.outside);
    });
  });
}
