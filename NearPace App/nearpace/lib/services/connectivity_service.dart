import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Contract for monitoring network reachability.
abstract interface class ConnectivityService {
  Future<bool> checkOnline();
  Stream<bool> get onConnectivityChanged;
}

/// Device connectivity implementation of [ConnectivityService] via `connectivity_plus`.
class SystemConnectivityService implements ConnectivityService {
  SystemConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> checkOnline() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      // Default to optimistic true if platform check fails
      return true;
    }
  }

  @override
  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map(
      (results) => results.any((r) => r != ConnectivityResult.none),
    );
  }
}

/// In-memory mock for [ConnectivityService] used in unit and widget tests.
class MockConnectivityService implements ConnectivityService {
  MockConnectivityService({bool initialOnline = true})
    : _isOnline = initialOnline,
      _controller = StreamController<bool>.broadcast();

  bool _isOnline;
  final StreamController<bool> _controller;

  @override
  Future<bool> checkOnline() async => _isOnline;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  void setOnline(bool online) {
    if (_isOnline != online) {
      _isOnline = online;
      _controller.add(online);
    }
  }

  void dispose() {
    _controller.close();
  }
}
