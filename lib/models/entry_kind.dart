import 'entry.dart';

/// The handful of things that actually happen, pre-wired so logging the
/// monthly scholarship is a couple of taps rather than a form.
///
/// Grouping the kinds keeps the Add screen readable as the list grows —
/// the user never sees the words "from" and "to".
enum KindGroup {
  income('Money in'),
  transfer('Between your own pots'),
  spending('Money out'),
  setup('One-off setup');

  const KindGroup(this.label);
  final String label;
}

enum Tone { positive, neutral, warning }

class EntryKind {
  const EntryKind({
    required this.id,
    required this.label,
    required this.hint,
    required this.group,
    required this.from,
    required this.to,
    this.source = Source.other,
    this.tone = Tone.neutral,
  });

  final String id;
  final String label;
  final String hint;
  final KindGroup group;
  final Ref from;
  final Ref to;
  final Source source;
  final Tone tone;

  static const List<EntryKind> all = [
    EntryKind(
      id: 'scholarship',
      label: 'Scholarship arrived',
      hint: 'The monthly college money landing in your account',
      group: KindGroup.income,
      from: Ref.outside,
      to: Ref.bank,
      source: Source.scholarship,
      tone: Tone.positive,
    ),
    EntryKind(
      id: 'salary',
      label: 'Salary or other money in',
      hint: 'Part-time pay, refunds, anything arriving',
      group: KindGroup.income,
      from: Ref.outside,
      to: Ref.bank,
      source: Source.parttime,
      tone: Tone.positive,
    ),
    EntryKind(
      id: 'save',
      label: 'Move to savings',
      hint: 'Out of the account and into the stash',
      group: KindGroup.transfer,
      from: Ref.bank,
      to: Ref.savings,
      tone: Tone.positive,
    ),
    EntryKind(
      id: 'dip',
      label: 'Took from savings',
      hint: 'Broke into the stash — logged and flagged',
      group: KindGroup.transfer,
      from: Ref.savings,
      to: Ref.outside,
      tone: Tone.warning,
    ),
    EntryKind(
      id: 'spend',
      label: 'Spent',
      hint: 'Rent, food, anything leaving the account',
      group: KindGroup.spending,
      from: Ref.bank,
      to: Ref.outside,
      tone: Tone.neutral,
    ),
    EntryKind(
      id: 'opening',
      label: 'Starting bank balance',
      hint: 'What was already in the account when you began — log this once',
      group: KindGroup.setup,
      from: Ref.outside,
      to: Ref.bank,
      tone: Tone.positive,
    ),
  ];

  static EntryKind byId(String? id) =>
      all.firstWhere((k) => k.id == id, orElse: () => all.first);

  static List<EntryKind> inGroup(KindGroup group) =>
      all.where((k) => k.group == group).toList();

  /// Best-effort reverse lookup, for labelling an entry in the history list.
  static EntryKind of(Entry entry) {
    return all.firstWhere(
      (k) => k.from == entry.from && k.to == entry.to && k.source == entry.source,
      orElse: () => all.firstWhere(
        (k) => k.from == entry.from && k.to == entry.to,
        orElse: () => all.first,
      ),
    );
  }
}
