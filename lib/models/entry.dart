/// MODEL layer (MVC). Pure Dart: no Flutter, no Firebase imports here, so the
/// whole thing is unit-testable and could be reused by a CLI or a server.
library;

/// Where money came from, for reporting.
enum Source {
  scholarship,
  parttime,
  other;

  static Source parse(String? raw) => Source.values.firstWhere(
    (s) => s.name == raw,
    orElse: () => Source.other,
  );
}

/// One end of a money movement.
///
/// Encoded as a short string so it fits a single Firestore field:
///   'outside'      the world beyond your money — wages arriving, rent leaving
///   'pot:bank'     the bank account
///   'pot:savings'  the untouchable savings stash
class Ref {
  const Ref._(this.value);

  final String value;

  static const Ref outside = Ref._('outside');
  static const Ref bank = Ref._('pot:bank');
  static const Ref savings = Ref._('pot:savings');

  static Ref parse(String? raw) => switch (raw) {
    'pot:bank' => bank,
    'pot:savings' => savings,
    _ => outside,
  };

  bool get isOutside => this == outside;
  bool get isPot => !isOutside;

  @override
  bool operator ==(Object other) => other is Ref && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// `amount` yen leaving [from] and arriving at [to].
///
/// One rule covers income, spending and transfers between your own pots:
///   pot balance = Σ(to == pot) − Σ(from == pot)
///
/// Because a transfer is a single record, the money leaving one pot and
/// arriving in another can never drift apart.
class Entry {
  const Entry({
    required this.id,
    required this.date,
    required this.amount,
    required this.from,
    required this.to,
    this.source = Source.other,
    this.note = '',
    required this.updatedAt,
    this.deleted = false,
    this.receiptPhoto,
  });

  final String id;

  /// Date only — the time of day is noise for a monthly ledger.
  final DateTime date;

  /// Whole yen, always positive. Direction lives in [from] and [to].
  final int amount;

  final Ref from;
  final Ref to;
  final Source source;
  final String note;
  final DateTime updatedAt;

  /// Soft delete, so a removal on the phone reaches the laptop rather than
  /// the laptop silently re-uploading the row.
  final bool deleted;

  /// Base64 JPEG of a receipt, captured with the device camera (Lecture 07).
  /// Kept small deliberately — see [FirestoreService] for the size guard.
  final String? receiptPhoto;

  bool get hasReceipt => receiptPhoto != null && receiptPhoto!.isNotEmpty;

  /// YYYY-MM, the key everything monthly is grouped by.
  String get monthKey =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

  Entry copyWith({
    DateTime? date,
    int? amount,
    Ref? from,
    Ref? to,
    Source? source,
    String? note,
    DateTime? updatedAt,
    bool? deleted,
    String? receiptPhoto,
  }) {
    return Entry(
      id: id,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      from: from ?? this.from,
      to: to ?? this.to,
      source: source ?? this.source,
      note: note ?? this.note,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      receiptPhoto: receiptPhoto ?? this.receiptPhoto,
    );
  }

  /// Serialisation is hand-written rather than generated, so the mapping stays
  /// readable in the code review the final presentation asks for.
  Map<String, dynamic> toJson() => {
    'date': _dateOnly(date),
    'amount': amount,
    'from': from.value,
    'to': to.value,
    'source': source.name,
    'note': note,
    'updatedAt': updatedAt.toIso8601String(),
    'deleted': deleted,
    if (receiptPhoto != null) 'receiptPhoto': receiptPhoto,
  };

  factory Entry.fromJson(String id, Map<String, dynamic> json) {
    return Entry(
      id: id,
      date: _parseDate(json['date']) ?? DateTime.now(),
      amount: (json['amount'] as num?)?.round() ?? 0,
      from: Ref.parse(json['from'] as String?),
      to: Ref.parse(json['to'] as String?),
      source: Source.parse(json['source'] as String?),
      note: json['note'] as String? ?? '',
      updatedAt: _parseTimestamp(json['updatedAt']) ?? DateTime.now(),
      deleted: json['deleted'] as bool? ?? false,
      receiptPhoto: json['receiptPhoto'] as String?,
    );
  }
}

String _dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime? _parseDate(Object? raw) {
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}

DateTime? _parseTimestamp(Object? raw) {
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}
