/// The savings plan itself. Small enough to live in shared_preferences on the
/// device and mirror to a single Firestore document.
class AppSettings {
  const AppSettings({
    this.monthlyTarget = 48000,
    this.goalMonths = 8,
    this.startMonth = '',
    this.goalName = "Parents' trip tickets",
  });

  /// Yen to set aside each month.
  final int monthlyTarget;

  /// How many months the plan runs for.
  final int goalMonths;

  /// YYYY-MM the plan started. Empty means "this month".
  final String startMonth;

  /// What the savings are actually for — shown on the tracker, because a
  /// number with a reason attached is easier to keep.
  final String goalName;

  int get goal => monthlyTarget * goalMonths;

  String get effectiveStartMonth {
    if (startMonth.isNotEmpty) return startMonth;
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
  }

  AppSettings copyWith({
    int? monthlyTarget,
    int? goalMonths,
    String? startMonth,
    String? goalName,
  }) {
    return AppSettings(
      monthlyTarget: monthlyTarget ?? this.monthlyTarget,
      goalMonths: goalMonths ?? this.goalMonths,
      startMonth: startMonth ?? this.startMonth,
      goalName: goalName ?? this.goalName,
    );
  }

  Map<String, dynamic> toJson() => {
    'monthlyTarget': monthlyTarget,
    'goalMonths': goalMonths,
    'startMonth': startMonth,
    'goalName': goalName,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    const fallback = AppSettings();
    return AppSettings(
      monthlyTarget: (json['monthlyTarget'] as num?)?.round() ?? fallback.monthlyTarget,
      goalMonths: (json['goalMonths'] as num?)?.round() ?? fallback.goalMonths,
      startMonth: json['startMonth'] as String? ?? fallback.startMonth,
      goalName: json['goalName'] as String? ?? fallback.goalName,
    );
  }
}
