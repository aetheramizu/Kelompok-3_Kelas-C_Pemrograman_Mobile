import '../domain/activity.dart';
import '../domain/geo_point.dart';
import '../domain/leaderboard_entry.dart';
import '../domain/run_group.dart';
import '../domain/user_profile.dart';
import '../domain/weather.dart';
import '../utils/formatters.dart';

/// Deterministic local preview fixtures used when backend services are not
/// connected. All records mirror the Firestore schema in `mvp-specification.md`.
class NearPaceMockData {
  const NearPaceMockData._();

  static UserProfile defaultProfile() => const UserProfile(
    uid: 'preview-runner-01',
    email: 'alief@nearpace.local',
    displayName: 'Alief Pratama',
    city: 'Makassar',
    showOnLeaderboard: false,
  );

  /// Realistic GPS loop coordinates for live recording preview simulation.
  static List<GeoPointLite> simulationLoop() => const [
    GeoPointLite(latitude: -5.14220, longitude: 119.40710, accuracyM: 7),
    GeoPointLite(latitude: -5.14145, longitude: 119.40745, accuracyM: 6),
    GeoPointLite(latitude: -5.14070, longitude: 119.40790, accuracyM: 8),
    GeoPointLite(latitude: -5.13995, longitude: 119.40835, accuracyM: 6),
    GeoPointLite(latitude: -5.13940, longitude: 119.40915, accuracyM: 7),
    GeoPointLite(latitude: -5.13930, longitude: 119.41010, accuracyM: 9),
    GeoPointLite(latitude: -5.13985, longitude: 119.41095, accuracyM: 6),
    GeoPointLite(latitude: -5.14065, longitude: 119.41125, accuracyM: 7),
    GeoPointLite(latitude: -5.14155, longitude: 119.41095, accuracyM: 6),
    GeoPointLite(latitude: -5.14230, longitude: 119.41030, accuracyM: 8),
    GeoPointLite(latitude: -5.14275, longitude: 119.40940, accuracyM: 6),
    GeoPointLite(latitude: -5.14270, longitude: 119.40830, accuracyM: 7),
    GeoPointLite(latitude: -5.14235, longitude: 119.40745, accuracyM: 6),
  ];

  static List<Activity> initialActivities(DateTime now) {
    final weekStart = NearPaceFormatters.startOfIsoWeek(now);
    final todayDay = DateTime(now.year, now.month, now.day);

    DateTime clampToWeek(int offsetFromMonday, int hour, int minute) {
      final candidate = weekStart.add(Duration(days: offsetFromMonday));
      final base = candidate.isAfter(todayDay) ? todayDay : candidate;
      return DateTime(base.year, base.month, base.day, hour, minute);
    }

    final run1Start = clampToWeek(
      (now.weekday - DateTime.monday).clamp(0, 6),
      6,
      12,
    );
    final run2Start = weekStart.add(
      const Duration(days: 2, hours: 17, minutes: 20),
    );
    final run3Start = weekStart.add(
      const Duration(days: 0, hours: 6, minutes: 35),
    );
    final prevWeekRun1 = weekStart.subtract(const Duration(days: 2, hours: -6));
    final prevWeekRun2 = weekStart.subtract(
      const Duration(days: 5, hours: -17),
    );

    return [
      Activity(
        id: 'act-001',
        startedAt: run1Start,
        endedAt: run1Start.add(const Duration(minutes: 31, seconds: 42)),
        distanceM: 6180,
        durationS: 1902,
        avgPaceSecPerKm: 1902 / 6.18,
        route: const [
          GeoPointLite(latitude: -5.1430, longitude: 119.4070),
          GeoPointLite(latitude: -5.1408, longitude: 119.4076),
          GeoPointLite(latitude: -5.1384, longitude: 119.4082),
          GeoPointLite(latitude: -5.1372, longitude: 119.4098),
          GeoPointLite(latitude: -5.1386, longitude: 119.4116),
          GeoPointLite(latitude: -5.1411, longitude: 119.4114),
          GeoPointLite(latitude: -5.1432, longitude: 119.4102),
          GeoPointLite(latitude: -5.1438, longitude: 119.4084),
          GeoPointLite(latitude: -5.1431, longitude: 119.4072),
        ],
        weather: WeatherSnapshot(
          temperatureC: 27.4,
          apparentC: 29.8,
          code: 1,
          fetchedAt: run1Start,
        ),
      ),
      Activity(
        id: 'act-002',
        startedAt: run2Start.isAfter(now)
            ? now.subtract(const Duration(days: 1, hours: 3))
            : run2Start,
        endedAt:
            (run2Start.isAfter(now)
                    ? now.subtract(const Duration(days: 1, hours: 3))
                    : run2Start)
                .add(const Duration(minutes: 25, seconds: 10)),
        distanceM: 4850,
        durationS: 1510,
        avgPaceSecPerKm: 1510 / 4.85,
        route: const [
          GeoPointLite(latitude: -5.1310, longitude: 119.4865),
          GeoPointLite(latitude: -5.1322, longitude: 119.4882),
          GeoPointLite(latitude: -5.1338, longitude: 119.4895),
          GeoPointLite(latitude: -5.1355, longitude: 119.4888),
          GeoPointLite(latitude: -5.1358, longitude: 119.4869),
          GeoPointLite(latitude: -5.1339, longitude: 119.4858),
          GeoPointLite(latitude: -5.1315, longitude: 119.4862),
        ],
        weather: WeatherSnapshot(
          temperatureC: 29.1,
          apparentC: 31.6,
          code: 2,
          fetchedAt: run2Start,
        ),
      ),
      Activity(
        id: 'act-003',
        startedAt: run3Start,
        endedAt: run3Start.add(const Duration(minutes: 40, seconds: 18)),
        distanceM: 7420,
        durationS: 2418,
        avgPaceSecPerKm: 2418 / 7.42,
        route: const [
          GeoPointLite(latitude: -5.1480, longitude: 119.4120),
          GeoPointLite(latitude: -5.1462, longitude: 119.4138),
          GeoPointLite(latitude: -5.1445, longitude: 119.4152),
          GeoPointLite(latitude: -5.1422, longitude: 119.4160),
          GeoPointLite(latitude: -5.1404, longitude: 119.4148),
          GeoPointLite(latitude: -5.1420, longitude: 119.4128),
          GeoPointLite(latitude: -5.1450, longitude: 119.4112),
          GeoPointLite(latitude: -5.1476, longitude: 119.4117),
        ],
        weather: WeatherSnapshot(
          temperatureC: 26.2,
          apparentC: 28.0,
          code: 0,
          fetchedAt: run3Start,
        ),
      ),
      Activity(
        id: 'act-004',
        startedAt: prevWeekRun1,
        endedAt: prevWeekRun1.add(const Duration(minutes: 53, seconds: 12)),
        distanceM: 10040,
        durationS: 3192,
        avgPaceSecPerKm: 3192 / 10.04,
        route: const [
          GeoPointLite(latitude: -5.1450, longitude: 119.4050),
          GeoPointLite(latitude: -5.1415, longitude: 119.4058),
          GeoPointLite(latitude: -5.1375, longitude: 119.4070),
          GeoPointLite(latitude: -5.1342, longitude: 119.4092),
          GeoPointLite(latitude: -5.1355, longitude: 119.4125),
          GeoPointLite(latitude: -5.1398, longitude: 119.4130),
          GeoPointLite(latitude: -5.1436, longitude: 119.4110),
          GeoPointLite(latitude: -5.1456, longitude: 119.4076),
          GeoPointLite(latitude: -5.1451, longitude: 119.4054),
        ],
        weather: WeatherSnapshot(
          temperatureC: 25.8,
          apparentC: 27.9,
          code: 3,
          fetchedAt: prevWeekRun1,
        ),
      ),
      Activity(
        id: 'act-005',
        startedAt: prevWeekRun2,
        endedAt: prevWeekRun2.add(const Duration(minutes: 19, seconds: 45)),
        distanceM: 3600,
        durationS: 1185,
        avgPaceSecPerKm: 1185 / 3.6,
        route: const [
          GeoPointLite(latitude: -5.1320, longitude: 119.4880),
          GeoPointLite(latitude: -5.1305, longitude: 119.4898),
          GeoPointLite(latitude: -5.1292, longitude: 119.4914),
          GeoPointLite(latitude: -5.1308, longitude: 119.4922),
          GeoPointLite(latitude: -5.1324, longitude: 119.4902),
          GeoPointLite(latitude: -5.1321, longitude: 119.4882),
        ],
        weather: null, // Demonstrates graceful "Conditions unavailable" state.
      ),
    ];
  }

  static List<LeaderboardEntry> initialLeaderboard(DateTime now) {
    final weekKey = NearPaceFormatters.isoWeekKey(now);
    return [
      LeaderboardEntry(
        uid: 'runner-nadia',
        displayName: 'Nadia Rahman',
        city: 'Makassar',
        weekKey: weekKey,
        distanceM: 34200,
        runCount: 5,
        updatedAt: now.subtract(const Duration(hours: 2)),
      ),
      LeaderboardEntry(
        uid: 'runner-bima',
        displayName: 'Bima Wijaya',
        city: 'Jakarta',
        weekKey: weekKey,
        distanceM: 29800,
        runCount: 4,
        updatedAt: now.subtract(const Duration(hours: 4)),
      ),
      LeaderboardEntry(
        uid: 'runner-rafli',
        displayName: 'Rafli Hidayat',
        city: 'Makassar',
        weekKey: weekKey,
        distanceM: 24650,
        runCount: 4,
        updatedAt: now.subtract(const Duration(hours: 6)),
      ),
      LeaderboardEntry(
        uid: 'runner-sinta',
        displayName: 'Sinta Dewi',
        city: 'Bandung',
        weekKey: weekKey,
        distanceM: 21400,
        runCount: 3,
        updatedAt: now.subtract(const Duration(hours: 9)),
      ),
      LeaderboardEntry(
        uid: 'runner-dimas',
        displayName: 'Dimas Santoso',
        city: 'Makassar',
        weekKey: weekKey,
        distanceM: 16200,
        runCount: 3,
        updatedAt: now.subtract(const Duration(hours: 11)),
      ),
      LeaderboardEntry(
        uid: 'runner-citra',
        displayName: 'Citra Lestari',
        city: 'Jakarta',
        weekKey: weekKey,
        distanceM: 14900,
        runCount: 2,
        updatedAt: now.subtract(const Duration(hours: 15)),
      ),
      LeaderboardEntry(
        uid: 'runner-fajar',
        displayName: 'Fajar Nugroho',
        city: 'Bandung',
        weekKey: weekKey,
        distanceM: 11350,
        runCount: 2,
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
    ];
  }

  /// Seeded joinable circle for local preview (current user is NOT yet a member
  /// so the empty state renders first, and code `NDP4CE` can be used to test joining).
  static List<RunGroup> initialPreviewGroups(DateTime now) {
    return [
      RunGroup(
        id: 'preview-circle-losari',
        name: 'Losari Sunrise Crew',
        description:
            'Weekly 25 km morning pace challenge around Pantai Losari.',
        inviteCode: 'NDP4CE',
        ownerUid: 'runner-nadia',
        memberUids: const ['runner-nadia', 'runner-rafli', 'runner-dimas'],
        weeklyGoalKm: 25.0,
        createdAt: now.subtract(const Duration(days: 14)),
      ),
    ];
  }

  static Map<String, List<GroupMemberRank>> initialPreviewGroupMembers(
    DateTime now,
  ) {
    final weekKey = NearPaceFormatters.isoWeekKey(now);
    return {
      'preview-circle-losari': [
        GroupMemberRank(
          uid: 'runner-nadia',
          displayName: 'Nadia Rahman',
          avatarId: 'pace_queen',
          weekKey: weekKey,
          distanceM: 34200,
          runCount: 5,
          avgPaceSecPerKm: 312,
          updatedAt: now.subtract(const Duration(hours: 2)),
        ),
        GroupMemberRank(
          uid: 'runner-rafli',
          displayName: 'Rafli Hidayat',
          avatarId: 'volt_sprinter',
          weekKey: weekKey,
          distanceM: 24650,
          runCount: 4,
          avgPaceSecPerKm: 334,
          updatedAt: now.subtract(const Duration(hours: 6)),
        ),
        GroupMemberRank(
          uid: 'runner-dimas',
          displayName: 'Dimas Santoso',
          avatarId: 'apex_wolf',
          weekKey: weekKey,
          distanceM: 16200,
          runCount: 3,
          avgPaceSecPerKm: 348,
          updatedAt: now.subtract(const Duration(hours: 11)),
        ),
      ],
    };
  }
}
