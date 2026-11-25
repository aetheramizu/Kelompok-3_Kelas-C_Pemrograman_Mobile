import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/run_checkpoint.dart';

/// Contract for persisting and restoring active in-flight running sessions.
abstract interface class RunCheckpointService {
  Future<void> saveCheckpoint(RunCheckpoint checkpoint);
  Future<RunCheckpoint?> loadCheckpoint();
  Future<void> clearCheckpoint();
}

/// SharedPreferences implementation of [RunCheckpointService].
class PreferencesRunCheckpointService implements RunCheckpointService {
  PreferencesRunCheckpointService({SharedPreferences? preferences})
    : _prefs = preferences;

  static const _key = 'nearpace_active_run_checkpoint';
  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<void> saveCheckpoint(RunCheckpoint checkpoint) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(_key, checkpoint.toJson());
    } catch (_) {
      // Degrade gracefully if storage write fails
    }
  }

  @override
  Future<RunCheckpoint?> loadCheckpoint() async {
    try {
      final prefs = await _getPrefs();
      final jsonStr = prefs.getString(_key);
      if (jsonStr == null || jsonStr.isEmpty) return null;
      return RunCheckpoint.fromJson(jsonStr);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clearCheckpoint() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_key);
    } catch (_) {
      // Ignore cleanup error
    }
  }
}

/// In-memory mock implementation of [RunCheckpointService] for tests.
class InMemoryRunCheckpointService implements RunCheckpointService {
  RunCheckpoint? _checkpoint;

  @override
  Future<void> saveCheckpoint(RunCheckpoint checkpoint) async {
    _checkpoint = checkpoint;
  }

  @override
  Future<RunCheckpoint?> loadCheckpoint() async => _checkpoint;

  @override
  Future<void> clearCheckpoint() async {
    _checkpoint = null;
  }
}
