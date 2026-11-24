import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/activity.dart';

/// Contract for persisting offline activities waiting to be synced to Firestore.
abstract interface class PendingSyncStorage {
  Future<List<Activity>> getPendingActivities();
  Future<void> addPendingActivity(Activity activity);
  Future<void> removePendingActivity(String activityId);
  Future<void> updatePendingActivity(Activity activity);
  Future<void> clear();
}

/// SharedPreferences implementation of [PendingSyncStorage].
class PreferencesPendingSyncStorage implements PendingSyncStorage {
  PreferencesPendingSyncStorage({SharedPreferences? preferences})
    : _prefs = preferences;

  SharedPreferences? _prefs;
  static const String _storageKey = 'nearpace_pending_sync_queue';

  Future<SharedPreferences> _getPrefs() async {
    final existing = _prefs;
    if (existing != null) return existing;
    final loaded = await SharedPreferences.getInstance();
    _prefs = loaded;
    return loaded;
  }

  @override
  Future<List<Activity>> getPendingActivities() async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => Activity.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> addPendingActivity(Activity activity) async {
    final list = await getPendingActivities();
    final index = list.indexWhere((a) => a.id == activity.id);
    final updated = List<Activity>.from(list);
    if (index >= 0) {
      updated[index] = activity;
    } else {
      updated.add(activity);
    }
    await _saveList(updated);
  }

  @override
  Future<void> removePendingActivity(String activityId) async {
    final list = await getPendingActivities();
    final updated = list.where((a) => a.id != activityId).toList();
    await _saveList(updated);
  }

  @override
  Future<void> updatePendingActivity(Activity activity) async {
    await addPendingActivity(activity);
  }

  @override
  Future<void> clear() async {
    final prefs = await _getPrefs();
    await prefs.remove(_storageKey);
  }

  Future<void> _saveList(List<Activity> list) async {
    final prefs = await _getPrefs();
    final serialized = jsonEncode(list.map((a) => a.toMap()).toList());
    await prefs.setString(_storageKey, serialized);
  }
}

/// In-memory implementation of [PendingSyncStorage] for tests.
class InMemoryPendingSyncStorage implements PendingSyncStorage {
  InMemoryPendingSyncStorage({List<Activity>? initial})
    : _storage = Map.fromEntries(
        (initial ?? const []).map((a) => MapEntry(a.id, a)),
      );

  final Map<String, Activity> _storage;

  @override
  Future<List<Activity>> getPendingActivities() async {
    return _storage.values.toList();
  }

  @override
  Future<void> addPendingActivity(Activity activity) async {
    _storage[activity.id] = activity;
  }

  @override
  Future<void> removePendingActivity(String activityId) async {
    _storage.remove(activityId);
  }

  @override
  Future<void> updatePendingActivity(Activity activity) async {
    _storage[activity.id] = activity;
  }

  @override
  Future<void> clear() async {
    _storage.clear();
  }
}
