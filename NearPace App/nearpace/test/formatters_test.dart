import 'package:flutter_test/flutter_test.dart';
import 'package:nearpace/utils/formatters.dart';

void main() {
  group('NearPaceFormatters', () {
    test('formats distances in km cleanly', () {
      expect(NearPaceFormatters.distanceKm(0), '0.00 km');
      expect(NearPaceFormatters.distanceKm(5240), '5.24 km');
      expect(NearPaceFormatters.distanceKm(10000, decimals: 1), '10.0 km');
      expect(NearPaceFormatters.distanceKm(-100), '0.00 km');
    });

    test('formats clock and compact durations', () {
      expect(
        NearPaceFormatters.durationClock(
          const Duration(minutes: 4, seconds: 9),
        ),
        '04:09',
      );
      expect(
        NearPaceFormatters.durationClock(
          const Duration(hours: 1, minutes: 5, seconds: 3),
        ),
        '1:05:03',
      );
      expect(
        NearPaceFormatters.durationCompact(
          const Duration(hours: 1, minutes: 36),
        ),
        '1h 36m',
      );
      expect(
        NearPaceFormatters.durationCompact(const Duration(minutes: 28)),
        '28m',
      );
    });

    test('formats pace and handles null or non-positive values', () {
      expect(NearPaceFormatters.paceWithUnit(null), '--:-- /km');
      expect(NearPaceFormatters.paceWithUnit(0), '--:-- /km');
      expect(NearPaceFormatters.paceWithUnit(double.nan), '--:-- /km');
      expect(NearPaceFormatters.paceWithUnit(315), '5:15 /km');
      expect(NearPaceFormatters.paceValue(299.6), '5:00');
    });

    test('computes ISO Monday week keys consistently', () {
      // Saturday Nov 21, 2026 -> Monday Nov 16, 2026.
      expect(
        NearPaceFormatters.isoWeekKey(DateTime(2026, 11, 21, 10, 0)),
        '2026-11-16',
      );
      // Monday itself maps to itself.
      expect(
        NearPaceFormatters.isoWeekKey(DateTime(2026, 11, 16, 6, 30)),
        '2026-11-16',
      );
      // Sunday Nov 22, 2026 -> Monday Nov 16, 2026.
      expect(
        NearPaceFormatters.isoWeekKey(DateTime(2026, 11, 22, 23, 59)),
        '2026-11-16',
      );
    });
  });
}
