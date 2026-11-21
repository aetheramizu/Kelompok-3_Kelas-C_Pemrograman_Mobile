import 'dart:math' as math;

/// A latitude/longitude pair with optional GPS accuracy and timestamp.
///
/// Kept independent of the geolocator plugin so distance logic is unit-testable.
class GeoPointLite {
  const GeoPointLite({
    required this.latitude,
    required this.longitude,
    this.accuracyM,
    this.recordedAt,
  });

  final double latitude;
  final double longitude;
  final double? accuracyM;
  final DateTime? recordedAt;

  static const double _earthRadiusM = 6371000;

  double distanceTo(GeoPointLite other) {
    final lat1 = latitude * math.pi / 180;
    final lat2 = other.latitude * math.pi / 180;
    final dLat = lat2 - lat1;
    final dLon = (other.longitude - longitude) * math.pi / 180;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * _earthRadiusM * math.asin(math.min(1, math.sqrt(a)));
  }

  Map<String, dynamic> toMap() => {'lat': latitude, 'lng': longitude};

  static GeoPointLite fromMap(Map<String, dynamic> map) => GeoPointLite(
    latitude: (map['lat'] as num).toDouble(),
    longitude: (map['lng'] as num).toDouble(),
  );

  @override
  String toString() =>
      'GeoPointLite(${latitude.toStringAsFixed(5)}, '
      '${longitude.toStringAsFixed(5)})';
}
