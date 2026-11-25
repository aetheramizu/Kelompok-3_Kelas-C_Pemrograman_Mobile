import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../domain/geo_point.dart';
import '../state/nearpace_controller.dart' show LocationPermissionStatus;

/// Contract for device GPS and location permissions.
abstract interface class LocationTrackingService {
  Future<LocationPermissionStatus> checkPermission();
  Future<LocationPermissionStatus> requestPermission();
  Future<bool> isLocationServiceEnabled();
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
  Future<GeoPointLite?> getLastKnownPosition();
  Stream<GeoPointLite> positionStream();
}

/// Geolocator plugin implementation of [LocationTrackingService].
class GeolocatorTrackingService implements LocationTrackingService {
  const GeolocatorTrackingService();

  @override
  Future<LocationPermissionStatus> checkPermission() async {
    final permission = await Geolocator.checkPermission();
    return _mapPermission(permission);
  }

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    final permission = await Geolocator.requestPermission();
    return _mapPermission(permission);
  }

  @override
  Future<bool> isLocationServiceEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  @override
  Future<bool> openAppSettings() async {
    return Geolocator.openAppSettings();
  }

  @override
  Future<bool> openLocationSettings() async {
    return Geolocator.openLocationSettings();
  }

  @override
  Future<GeoPointLite?> getLastKnownPosition() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position == null) return null;
      return GeoPointLite(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyM: position.accuracy,
        recordedAt: position.timestamp,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<GeoPointLite> positionStream() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2,
    );

    return Geolocator.getPositionStream(locationSettings: settings)
        .map((position) {
          return GeoPointLite(
            latitude: position.latitude,
            longitude: position.longitude,
            accuracyM: position.accuracy,
            recordedAt: position.timestamp,
          );
        });
  }

  static LocationPermissionStatus _mapPermission(
    LocationPermission permission,
  ) {
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationPermissionStatus.granted;
      case LocationPermission.denied:
        return LocationPermissionStatus.denied;
      case LocationPermission.deniedForever:
      case LocationPermission.unableToDetermine:
        return LocationPermissionStatus.deniedForever;
    }
  }
}

/// Simulated implementation of [LocationTrackingService] for tests and local preview.
class SimulatedLocationService implements LocationTrackingService {
  SimulatedLocationService({
    LocationPermissionStatus initialPermission =
        LocationPermissionStatus.notRequested,
    this.serviceEnabled = true,
    List<GeoPointLite>? mockRoute,
  }) : _permission = initialPermission,
       _mockRoute = mockRoute ?? const [],
       _controller = StreamController<GeoPointLite>.broadcast();

  LocationPermissionStatus _permission;
  bool serviceEnabled;
  final List<GeoPointLite> _mockRoute;
  final StreamController<GeoPointLite> _controller;

  @override
  Future<LocationPermissionStatus> checkPermission() async => _permission;

  @override
  Future<LocationPermissionStatus> requestPermission() async => _permission;

  void setPermission(LocationPermissionStatus status) {
    _permission = status;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<GeoPointLite?> getLastKnownPosition() async =>
      _mockRoute.isNotEmpty ? _mockRoute.first : null;

  @override
  Stream<GeoPointLite> positionStream() {
    if (_mockRoute.isNotEmpty) {
      scheduleMicrotask(() {
        for (final pt in _mockRoute) {
          if (!_controller.isClosed) {
            _controller.add(pt);
          }
        }
      });
    }
    return _controller.stream;
  }

  void emitPoint(GeoPointLite point) {
    if (!_controller.isClosed) {
      _controller.add(point);
    }
  }

  void dispose() {
    _controller.close();
  }
}
