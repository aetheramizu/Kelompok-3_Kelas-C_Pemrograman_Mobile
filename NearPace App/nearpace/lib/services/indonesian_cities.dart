import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

/// Representation of an Indonesian city/regency with centroid coordinates.
class IndonesianCity {
  const IndonesianCity({
    required this.name,
    required this.province,
    required this.lat,
    required this.lng,
  });

  final String name;
  final String province;
  final double lat;
  final double lng;

  factory IndonesianCity.fromJson(Map<String, dynamic> json) {
    return IndonesianCity(
      name: json['name'] as String,
      province: json['province'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'province': province,
    'lat': lat,
    'lng': lng,
  };
}

/// Service for loading Indonesian cities and matching coordinates via Haversine distance.
class IndonesianCitiesService {
  static List<IndonesianCity>? _cachedCities;

  /// Bundled fallback cities in case asset bundle is unavailable in unit tests.
  static const List<IndonesianCity> fallbackCities = [
    IndonesianCity(
      name: 'Jakarta Pusat',
      province: 'DKI Jakarta',
      lat: -6.186486,
      lng: 106.834091,
    ),
    IndonesianCity(
      name: 'Jakarta Selatan',
      province: 'DKI Jakarta',
      lat: -6.261493,
      lng: 106.810600,
    ),
    IndonesianCity(
      name: 'Jakarta Barat',
      province: 'DKI Jakarta',
      lat: -6.168329,
      lng: 106.758849,
    ),
    IndonesianCity(
      name: 'Jakarta Timur',
      province: 'DKI Jakarta',
      lat: -6.225014,
      lng: 106.900447,
    ),
    IndonesianCity(
      name: 'Jakarta Utara',
      province: 'DKI Jakarta',
      lat: -6.138414,
      lng: 106.864115,
    ),
    IndonesianCity(
      name: 'Surabaya',
      province: 'Jawa Timur',
      lat: -7.257472,
      lng: 112.752088,
    ),
    IndonesianCity(
      name: 'Bandung',
      province: 'Jawa Barat',
      lat: -6.917464,
      lng: 107.619123,
    ),
    IndonesianCity(
      name: 'Medan',
      province: 'Sumatera Utara',
      lat: 3.595196,
      lng: 98.672223,
    ),
    IndonesianCity(
      name: 'Semarang',
      province: 'Jawa Tengah',
      lat: -6.9932,
      lng: 110.4203,
    ),
    IndonesianCity(
      name: 'Makassar',
      province: 'Sulawesi Selatan',
      lat: -5.147665,
      lng: 119.432732,
    ),
    IndonesianCity(
      name: 'Palembang',
      province: 'Sumatera Selatan',
      lat: -2.990934,
      lng: 104.756554,
    ),
    IndonesianCity(
      name: 'Tangerang',
      province: 'Banten',
      lat: -6.178306,
      lng: 106.631889,
    ),
    IndonesianCity(
      name: 'Tangerang Selatan',
      province: 'Banten',
      lat: -6.288892,
      lng: 106.717892,
    ),
    IndonesianCity(
      name: 'Depok',
      province: 'Jawa Barat',
      lat: -6.402484,
      lng: 106.794241,
    ),
    IndonesianCity(
      name: 'Bekasi',
      province: 'Jawa Barat',
      lat: -6.238270,
      lng: 106.975571,
    ),
    IndonesianCity(
      name: 'Bogor',
      province: 'Jawa Barat',
      lat: -6.597147,
      lng: 106.806039,
    ),
    IndonesianCity(
      name: 'Yogyakarta',
      province: 'DI Yogyakarta',
      lat: -7.795580,
      lng: 110.369490,
    ),
    IndonesianCity(
      name: 'Surakarta',
      province: 'Jawa Tengah',
      lat: -7.575489,
      lng: 110.824326,
    ),
    IndonesianCity(
      name: 'Denpasar',
      province: 'Bali',
      lat: -8.670458,
      lng: 115.212629,
    ),
    IndonesianCity(
      name: 'Malang',
      province: 'Jawa Timur',
      lat: -7.966620,
      lng: 112.632632,
    ),
    IndonesianCity(
      name: 'Batam',
      province: 'Kepulauan Riau',
      lat: 1.130141,
      lng: 104.052948,
    ),
  ];

  /// Loads cities from `assets/data/indonesia_cities.json`, falling back to [fallbackCities].
  static Future<List<IndonesianCity>> loadCities({AssetBundle? bundle}) async {
    if (_cachedCities != null) return _cachedCities!;
    try {
      final assetBundle = bundle ?? rootBundle;
      final raw = await assetBundle.loadString(
        'assets/data/indonesia_cities.json',
      );
      final decoded = jsonDecode(raw) as List<dynamic>;
      _cachedCities = decoded
          .map((item) => IndonesianCity.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
      return _cachedCities!;
    } catch (_) {
      _cachedCities = fallbackCities;
      return _cachedCities!;
    }
  }

  /// Calculates Haversine distance in kilometers between two lat/lng coordinates.
  static double haversineDistanceKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = (lat2 - lat1) * (math.pi / 180.0);
    final dLng = (lng2 - lng1) * (math.pi / 180.0);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180.0)) *
            math.cos(lat2 * (math.pi / 180.0)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  /// Finds the closest canonical Indonesian city to the given coordinate.
  static IndonesianCity findNearestCity(
    double lat,
    double lng, {
    List<IndonesianCity>? customCities,
  }) {
    final list = customCities ?? _cachedCities ?? fallbackCities;
    if (list.isEmpty) {
      return const IndonesianCity(
        name: 'Jakarta',
        province: 'DKI Jakarta',
        lat: -6.2088,
        lng: 106.8456,
      );
    }

    IndonesianCity closest = list.first;
    var minDistance = double.infinity;

    for (final city in list) {
      final distance = haversineDistanceKm(lat, lng, city.lat, city.lng);
      if (distance < minDistance) {
        minDistance = distance;
        closest = city;
      }
    }
    return closest;
  }

  /// Searches cities matching query string in name or province.
  static List<IndonesianCity> searchCities(
    String query, {
    List<IndonesianCity>? customCities,
  }) {
    final list = customCities ?? _cachedCities ?? fallbackCities;
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return list;

    return list.where((c) {
      return c.name.toLowerCase().contains(cleanQuery) ||
          c.province.toLowerCase().contains(cleanQuery);
    }).toList();
  }
}
