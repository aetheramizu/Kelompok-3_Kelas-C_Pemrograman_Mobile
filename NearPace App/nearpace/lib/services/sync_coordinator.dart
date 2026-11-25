import 'dart:async';

import 'connectivity_service.dart';

/// Contract for coordinating offline-to-online synchronization.
abstract interface class SyncCoordinator {
  bool get isOnline;
  Stream<bool> get isOnlineStream;
  Future<int> syncPending();
  void onAppResumed();
  void dispose();
}

/// Orchestrator for sync triggers: connectivity transitions, app resume, and pull-to-refresh.
class NearPaceSyncCoordinator implements SyncCoordinator {
  NearPaceSyncCoordinator({
    required ConnectivityService connectivityService,
    required Future<int> Function() onSyncRequested,
  }) : _connectivity = connectivityService,
       _syncHandler = onSyncRequested {
    _init();
  }

  final ConnectivityService _connectivity;
  final Future<int> Function() _syncHandler;
  StreamSubscription<bool>? _connectivitySub;
  bool _isOnline = true;
  bool _isSyncing = false;
  bool _disposed = false;

  final StreamController<bool> _onlineStreamController =
      StreamController<bool>.broadcast();

  void _emitOnline(bool value) {
    if (!_disposed && !_onlineStreamController.isClosed) {
      _onlineStreamController.add(value);
    }
  }

  Future<void> _init() async {
    final online = await _connectivity.checkOnline();
    if (_disposed) return;
    _isOnline = online;
    _emitOnline(_isOnline);

    _connectivitySub = _connectivity.onConnectivityChanged.listen((online) {
      if (_disposed) return;
      final wasOffline = !_isOnline;
      _isOnline = online;
      _emitOnline(online);

      if (wasOffline && online) {
        // Automatically sync when internet reconnects.
        unawaited(syncPending());
      }
    });
  }

  @override
  bool get isOnline => _isOnline;

  @override
  Stream<bool> get isOnlineStream => _onlineStreamController.stream;

  @override
  Future<int> syncPending() async {
    if (_disposed || _isSyncing) return 0;
    _isSyncing = true;
    try {
      return await _syncHandler();
    } finally {
      _isSyncing = false;
    }
  }

  @override
  void onAppResumed() {
    if (_disposed) return;
    unawaited(_handleAppResumed());
  }

  Future<void> _handleAppResumed() async {
    final online = await _connectivity.checkOnline();
    if (_disposed) return;
    _isOnline = online;
    _emitOnline(online);
    if (online) {
      await syncPending();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _connectivitySub?.cancel();
    if (!_onlineStreamController.isClosed) {
      _onlineStreamController.close();
    }
  }
}
