import 'package:flutter_test/flutter_test.dart';
import 'package:nearpace/domain/geo_point.dart';
import 'package:nearpace/domain/run_session.dart';

void main() {
  group('GeoPointLite', () {
    test(
      'computes accurate Haversine distance between two known coordinates',
      () {
        // Monas (Jakarta): -6.175392, 106.827153
        // Bundaran HI (Jakarta): -6.195000, 106.823000
        // Actual ground distance is ~2.2 km (~2220 m)
        const monas = GeoPointLite(latitude: -6.175392, longitude: 106.827153);
        const bundaranHi = GeoPointLite(
          latitude: -6.195000,
          longitude: 106.823000,
        );

        final distance = monas.distanceTo(bundaranHi);
        expect(distance, greaterThan(2100));
        expect(distance, lessThan(2300));
      },
    );

    test('distance to identical point is zero', () {
      const p = GeoPointLite(latitude: -5.147665, longitude: 119.432732);
      expect(p.distanceTo(p), closeTo(0.0, 0.001));
    });
  });

  group('RunSession GPS Filtering & Math', () {
    late DateTime start;
    late RunSession session;

    setUp(() {
      start = DateTime(2026, 11, 22, 7, 0, 0);
      session = RunSession(startedAt: start);
    });

    test('accepts valid initial sample and subsequent realistic steps', () {
      const p1 = GeoPointLite(
        latitude: -5.147665,
        longitude: 119.432732,
        accuracyM: 5.0,
      );
      final accepted1 = session.addSample(p1, start);
      expect(accepted1, isTrue);
      expect(session.acceptedSamples, 1);

      // 10 metres away after 2 seconds (~5 m/s, well within 12 m/s limit)
      const p2 = GeoPointLite(
        latitude: -5.147755,
        longitude: 119.432732,
        accuracyM: 6.0,
      );
      final accepted2 = session.addSample(
        p2,
        start.add(const Duration(seconds: 2)),
      );
      expect(accepted2, isTrue);
      expect(session.acceptedSamples, 2);
      expect(session.distanceMeters, greaterThan(9.0));
      expect(session.distanceMeters, lessThan(11.0));
    });

    test('rejects fixes with accuracy worse than 35m', () {
      const accurate = GeoPointLite(
        latitude: -5.147665,
        longitude: 119.432732,
        accuracyM: 10.0,
      );
      expect(session.addSample(accurate, start), isTrue);

      const inaccurate = GeoPointLite(
        latitude: -5.147800,
        longitude: 119.432732,
        accuracyM: 45.0, // > 35m
      );
      final accepted = session.addSample(
        inaccurate,
        start.add(const Duration(seconds: 3)),
      );
      expect(accepted, isFalse);
      expect(session.rejectedSamples, 1);
      expect(session.acceptedSamples, 1);
    });

    test('rejects jitter movement under 1.5m', () {
      const p1 = GeoPointLite(
        latitude: -5.147665,
        longitude: 119.432732,
        accuracyM: 4.0,
      );
      session.addSample(p1, start);

      // Microscopic movement (~0.2m)
      const jitter = GeoPointLite(
        latitude: -5.147666,
        longitude: 119.432732,
        accuracyM: 4.0,
      );
      final accepted = session.addSample(
        jitter,
        start.add(const Duration(seconds: 1)),
      );
      expect(accepted, isFalse);
      expect(session.acceptedSamples, 1);
    });

    test('rejects implausible speed jumps (> 12 m/s or ~43 km/h)', () {
      const p1 = GeoPointLite(
        latitude: -5.147665,
        longitude: 119.432732,
        accuracyM: 5.0,
      );
      session.addSample(p1, start);

      // 100 metres jump in 1 second (= 100 m/s > 12 m/s)
      const teleport = GeoPointLite(
        latitude: -5.148565,
        longitude: 119.432732,
        accuracyM: 5.0,
      );
      final accepted = session.addSample(
        teleport,
        start.add(const Duration(seconds: 1)),
      );
      expect(accepted, isFalse);
      expect(session.rejectedSamples, 1);
      expect(session.acceptedSamples, 1);
    });

    test('handles pause, resume, and elapsed duration math correctly', () {
      expect(
        session.elapsedAt(start.add(const Duration(seconds: 10))),
        const Duration(seconds: 10),
      );

      // Pause at +10s
      final pauseTime = start.add(const Duration(seconds: 10));
      session.pause(pauseTime);
      expect(session.isPaused, isTrue);

      // Elapsed stays at 10s even when time advances to +25s
      expect(
        session.elapsedAt(start.add(const Duration(seconds: 25))),
        const Duration(seconds: 10),
      );

      // GPS points incoming during pause are rejected
      const p = GeoPointLite(latitude: -5.147665, longitude: 119.432732);
      expect(
        session.addSample(p, start.add(const Duration(seconds: 15))),
        isFalse,
      );

      // Resume at +30s (20s paused total)
      final resumeTime = start.add(const Duration(seconds: 30));
      session.resume(resumeTime);
      expect(session.isPaused, isFalse);

      // At +40s, elapsed should be 40s - 20s paused = 20s
      expect(
        session.elapsedAt(start.add(const Duration(seconds: 40))),
        const Duration(seconds: 20),
      );
    });

    test('calculates pace correctly once distance exceeds 50m', () {
      const p1 = GeoPointLite(latitude: -5.147665, longitude: 119.432732);
      session.addSample(p1, start);

      // 100m away in 30 seconds
      // 100m = 0.1km. 30s / 0.1km = 300 sec/km (5:00 /km)
      const p2 = GeoPointLite(latitude: -5.148565, longitude: 119.432732);
      // Wait, 100m over 20 seconds = 5 m/s (valid < 12 m/s)
      session.addSample(p2, start.add(const Duration(seconds: 20)));

      final pace = session.paceSecPerKmAt(
        start.add(const Duration(seconds: 30)),
      );
      expect(pace, isNotNull);
      expect(pace!, greaterThan(250));
      expect(pace, lessThan(350));
    });
  });
}
