import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_settings.dart';
import '../models/entry.dart';

/// Lecture 09: Using Cloud APIs 2 — Realtime collaboration.
///
/// Data is stored per user:
///   users/{uid}/entries/{entryId}
///   users/{uid}/settings/app
///
/// Scoping by uid lets the security rule be genuinely per-user, rather than
/// the lecture's simplified `if request.auth != null` which lets any signed-in
/// user read anyone's documents.
class FirestoreService {
  FirestoreService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Firestore caches reads and queues writes on device by default, which is
  /// why this app works with no signal and needs no hand-written sync layer.
  static Future<void> enableOfflinePersistence() async {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  CollectionReference<Map<String, dynamic>> _entries(String uid) =>
      _db.collection('users').doc(uid).collection('entries');

  DocumentReference<Map<String, dynamic>> _settings(String uid) =>
      _db.collection('users').doc(uid).collection('settings').doc('app');

  /// Realtime listener. Every device on this account receives the new list
  /// within a moment of any of them writing — this is the demo.
  Stream<List<Entry>> watchEntries(String uid) {
    return _entries(uid).snapshots().map((snapshot) {
      final entries = snapshot.docs
          .map((doc) => Entry.fromJson(doc.id, doc.data()))
          .where((e) => !e.deleted)
          .toList();
      entries.sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        return byDate != 0 ? byDate : b.updatedAt.compareTo(a.updatedAt);
      });
      return entries;
    });
  }

  Stream<AppSettings> watchSettings(String uid) {
    return _settings(uid).snapshots().map((doc) {
      final data = doc.data();
      return data == null ? const AppSettings() : AppSettings.fromJson(data);
    });
  }

  /// Let Firestore mint the id. Doing it client-side means the document can be
  /// written to the offline cache immediately and keeps the same id when it
  /// eventually reaches the server.
  String newEntryId(String uid) => _entries(uid).doc().id;

  /// A Firestore document is capped at 1 MiB. A downscaled receipt photo is
  /// far below that, but the guard means a surprise can never silently fail
  /// the whole write.
  static const int maxPhotoBytes = 700 * 1024;

  Future<void> upsertEntry(String uid, Entry entry) async {
    final json = entry.toJson();
    final photo = json['receiptPhoto'];
    if (photo is String && photo.length > maxPhotoBytes) {
      throw StateError(
        'Receipt photo is too large to store (${photo.length ~/ 1024} KB). '
        'Retake it at a lower resolution.',
      );
    }
    await _entries(uid).doc(entry.id).set(json);
  }

  /// Soft delete: the document stays, flagged, so other devices learn about
  /// the removal instead of re-uploading their cached copy.
  Future<void> deleteEntry(String uid, String entryId) async {
    await _entries(uid).doc(entryId).set({
      'deleted': true,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<void> saveSettings(String uid, AppSettings settings) async {
    await _settings(uid).set(settings.toJson(), SetOptions(merge: true));
  }

  /// FirebaseException codes are opaque in the UI; name the common ones.
  static String describe(Object error) {
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' =>
          'Permission denied — check the Firestore security rules are published.',
        'unavailable' => 'Cannot reach Firestore. Changes are saved on this device.',
        'not-found' => 'That record no longer exists.',
        _ => error.message ?? 'Firestore error (${error.code}).',
      };
    }
    if (error is StateError) return error.message;
    return error.toString();
  }
}
