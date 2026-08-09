import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

/// On-device persistence via shared_preferences (Lecture 06).
///
/// Only the plan settings live here. Entries do not need it: Firestore's own
/// offline cache already holds them, and duplicating that would mean writing
/// the merge logic this app deliberately avoids.
///
/// JSON encode/decode uses `dart:convert`, as shown in Lecture 09.
class LocalStore {
  static const _settingsKey = 'savingspad.settings';

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null) return const AppSettings();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return AppSettings.fromJson(decoded);
    } on FormatException {
      // Corrupt value: fall through to defaults rather than crashing on boot.
    }
    return const AppSettings();
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }
}
