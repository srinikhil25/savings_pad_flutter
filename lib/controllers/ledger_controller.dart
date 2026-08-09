import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../models/entry.dart';
import '../models/entry_kind.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/local_store.dart';
import '../utils/calc.dart';

/// CONTROLLER layer (MVC).
///
/// A [ChangeNotifier] exposed to the widget tree with Provider — which the
/// responsive-design lecture describes as "a wrapper around InheritedWidget".
/// Views read state from here and call methods on it; they never touch
/// FirebaseAuth or FirebaseFirestore directly.
class LedgerController extends ChangeNotifier {
  LedgerController({
    AuthService? auth,
    FirestoreService? db,
    LocalStore? local,
  })  : _auth = auth ?? AuthService(),
        _db = db ?? FirestoreService(),
        _local = local ?? LocalStore();

  final AuthService _auth;
  final FirestoreService _db;
  final LocalStore _local;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<List<Entry>>? _entriesSub;
  StreamSubscription<AppSettings>? _settingsSub;

  User? _user;
  List<Entry> _entries = const [];
  AppSettings _settings = const AppSettings();
  bool _loading = true;
  String? _error;

  User? get user => _user;
  bool get isSignedIn => _user != null;
  List<Entry> get entries => _entries;
  AppSettings get settings => _settings;
  bool get loading => _loading;
  String? get error => _error;

  // --- derived state, all delegated to the pure functions in calc.dart ------

  int get bank => bankBalance(_entries);
  int get savings => savingsBalance(_entries);
  Progress get progress => computeProgress(_entries, _settings);
  List<LedgerAlert> get alerts => computeAlerts(_entries, _settings);
  bool get needsAttention => alerts.any((a) => a.needsAttention);
  List<String> get months => activeMonths(_entries);
  MonthStats monthStats(String key) => statsFor(_entries, key);

  List<Entry> entriesIn(String monthKey) =>
      _entries.where((e) => e.monthKey == monthKey).toList();

  /// Settings are read from the device first so the goal name and target are
  /// correct on the very first frame, before Firestore has answered.
  Future<void> init() async {
    _settings = await _local.loadSettings();
    notifyListeners();

    _authSub = _auth.authStateChanges.listen((user) {
      _user = user;
      _error = null;
      if (user == null) {
        _unbind();
        _entries = const [];
        _loading = false;
      } else {
        _bind(user.uid);
      }
      notifyListeners();
    });
  }

  void _bind(String uid) {
    _unbind();
    _loading = true;

    _entriesSub = _db.watchEntries(uid).listen(
      (entries) {
        _entries = entries;
        _loading = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object e) {
        _error = FirestoreService.describe(e);
        _loading = false;
        notifyListeners();
      },
    );

    _settingsSub = _db.watchSettings(uid).listen(
      (remote) {
        _settings = remote;
        _local.saveSettings(remote);
        notifyListeners();
      },
      onError: (Object e) {
        _error = FirestoreService.describe(e);
        notifyListeners();
      },
    );
  }

  void _unbind() {
    _entriesSub?.cancel();
    _entriesSub = null;
    _settingsSub?.cancel();
    _settingsSub = null;
  }

  // --- commands -------------------------------------------------------------

  /// Returns null on success, or a message to show the user.
  Future<String?> addEntry({
    required EntryKind kind,
    required int amount,
    required DateTime date,
    String note = '',
    String? receiptPhoto,
  }) async {
    final uid = _auth.uid;
    if (uid == null) return 'Sign in first.';
    if (amount <= 0) return 'Enter an amount above zero.';

    final entry = Entry(
      id: _db.newEntryId(uid),
      date: DateTime(date.year, date.month, date.day),
      amount: amount,
      from: kind.from,
      to: kind.to,
      source: kind.source,
      note: note.trim(),
      updatedAt: DateTime.now(),
      receiptPhoto: receiptPhoto,
    );

    try {
      // Not awaited on purpose for the offline case: Firestore writes to the
      // local cache synchronously and the stream emits straight away, so the
      // UI updates with no connection. The future completes on reconnect.
      unawaited(_db.upsertEntry(uid, entry).catchError((Object e) {
        _error = FirestoreService.describe(e);
        notifyListeners();
      }));
      return null;
    } catch (e) {
      return FirestoreService.describe(e);
    }
  }

  Future<String?> deleteEntry(String entryId) async {
    final uid = _auth.uid;
    if (uid == null) return 'Sign in first.';
    try {
      unawaited(_db.deleteEntry(uid, entryId));
      return null;
    } catch (e) {
      return FirestoreService.describe(e);
    }
  }

  Future<void> updateSettings(AppSettings next) async {
    _settings = next;
    notifyListeners();
    await _local.saveSettings(next);
    final uid = _auth.uid;
    if (uid != null) {
      unawaited(_db.saveSettings(uid, next).catchError((Object e) {
        _error = FirestoreService.describe(e);
        notifyListeners();
      }));
    }
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  // --- auth passthrough -----------------------------------------------------

  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signIn(email: email, password: password);
      return null;
    } catch (e) {
      return AuthService.describe(e);
    }
  }

  Future<String?> signUp(String email, String password) async {
    try {
      await _auth.signUp(email: email, password: password);
      return null;
    } catch (e) {
      return AuthService.describe(e);
    }
  }

  Future<void> signOut() => _auth.signOut();

  @override
  void dispose() {
    _authSub?.cancel();
    _unbind();
    super.dispose();
  }
}
