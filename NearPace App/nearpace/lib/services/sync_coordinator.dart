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

  final StreamController<bool> _onlineStreamController =
      StreamController<bool>.broadcast();

  Future<void> _init() async {
    _isOnline = await _connectivity.checkOnline();
    _onlineStreamController.add(_isOnline);

    _connectivitySub = _connectivity.onConnectivityChanged.listen((online) {
      final wasOffline = !_isOnline;
      _isOnline = online;
      _onlineStreamController.add(online);

      if (wasOffline && online) {
        // Automatically sync when internet reconnects
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
    if (_isSyncing) return 0;
    _isSyncing = true;
    try {
      return await _syncHandler();
    } finally {
      _isSyncing = false;
    }
  }

  @override
  void onAppResumed() {
    unawaited(_handleAppResumed());
  }

  Future<void> _handleAppResumed() async {
    final online = await _connectivity.checkOnline();
    _isOnline = online;
    _onlineStreamController.add(online);
    if (online) {
      await syncPending();
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _onlineStreamController.close();
  }
}
