import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/activity.dart';

/// Contract for persisting offline activities waiting to be synced to Firestore.
abstract interface class PendingSyncStorage {
  Future<List<Activity>> getPendingActivities({String? uid});
  Future<void> addPendingActivity(Activity activity, {String? uid});
  Future<void> removePendingActivity(String activityId, {String? uid});
  Future<void> updatePendingActivity(Activity activity, {String? uid});
  Future<void> clear({String? uid});
}

/// SharedPreferences implementation of [PendingSyncStorage].
class PreferencesPendingSyncStorage implements PendingSyncStorage {
  PreferencesPendingSyncStorage({SharedPreferences? preferences})
    : _prefs = preferences;

  SharedPreferences? _prefs;
  static const String _storageKey = 'nearpace_pending_sync_queue';

  String _keyForUid(String? uid) {
    final trimmed = uid?.trim();
    if (trimmed == null || trimmed.isEmpty) return _storageKey;
    return '${_storageKey}_$trimmed';
  }

  Future<SharedPreferences> _getPrefs() async {
    final existing = _prefs;
    if (existing != null) return existing;
    final loaded = await SharedPreferences.getInstance();
    _prefs = loaded;
    return loaded;
  }

  @override
  Future<List<Activity>> getPendingActivities({String? uid}) async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_keyForUid(uid));
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final activities = <Activity>[];
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        try {
          activities.add(Activity.fromMap(item));
        } catch (_) {
          // Skip malformed entries rather than dropping the entire queue.
        }
      }
      return activities;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> addPendingActivity(Activity activity, {String? uid}) async {
    final list = await getPendingActivities(uid: uid);
    final index = list.indexWhere((a) => a.id == activity.id);
    final updated = List<Activity>.from(list);
    if (index >= 0) {
      updated[index] = activity;
    } else {
      updated.add(activity);
    }
    await _saveList(updated, uid: uid);
  }

  @override
  Future<void> removePendingActivity(String activityId, {String? uid}) async {
    final list = await getPendingActivities(uid: uid);
    final updated = list.where((a) => a.id != activityId).toList();
    await _saveList(updated, uid: uid);
  }

  @override
  Future<void> updatePendingActivity(Activity activity, {String? uid}) async {
    await addPendingActivity(activity, uid: uid);
  }

  @override
  Future<void> clear({String? uid}) async {
    final prefs = await _getPrefs();
    await prefs.remove(_keyForUid(uid));
  }

  Future<void> _saveList(List<Activity> list, {String? uid}) async {
    final prefs = await _getPrefs();
    final serialized = jsonEncode(list.map((a) => a.toMap()).toList());
    await prefs.setString(_keyForUid(uid), serialized);
  }
}

/// In-memory implementation of [PendingSyncStorage] for tests.
class InMemoryPendingSyncStorage implements PendingSyncStorage {
  InMemoryPendingSyncStorage({List<Activity>? initial, String? initialUid}) {
    final initialList = initial ?? const <Activity>[];
    if (initialList.isNotEmpty) {
      final bucket = _bucketFor(initialUid);
      for (final a in initialList) {
        bucket[a.id] = a;
      }
    }
  }

  final Map<String, Map<String, Activity>> _buckets = {};

  Map<String, Activity> _bucketFor(String? uid) {
    final key = uid?.trim() ?? '';
    return _buckets.putIfAbsent(key, () => <String, Activity>{});
  }

  @override
  Future<List<Activity>> getPendingActivities({String? uid}) async {
    if (uid != null && uid.trim().isNotEmpty) {
      return _bucketFor(uid).values.toList();
    }
    return _buckets.values.expand((bucket) => bucket.values).toList();
  }

  @override
  Future<void> addPendingActivity(Activity activity, {String? uid}) async {
    _bucketFor(uid)[activity.id] = activity;
  }

  @override
  Future<void> removePendingActivity(String activityId, {String? uid}) async {
    if (uid != null && uid.trim().isNotEmpty) {
      _bucketFor(uid).remove(activityId);
      return;
    }
    for (final bucket in _buckets.values) {
      bucket.remove(activityId);
    }
  }

  @override
  Future<void> updatePendingActivity(Activity activity, {String? uid}) async {
    _bucketFor(uid)[activity.id] = activity;
  }

  @override
  Future<void> clear({String? uid}) async {
    if (uid == null || uid.trim().isEmpty) {
      _buckets.clear();
    } else {
      _bucketFor(uid).clear();
    }
  }
}
