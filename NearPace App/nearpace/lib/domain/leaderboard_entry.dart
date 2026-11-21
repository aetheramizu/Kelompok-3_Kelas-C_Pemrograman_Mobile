/// Public weekly aggregate stored at `leaderboard/{weekKey}_{uid}`.
///
/// Deliberately excludes private fields such as email addresses or GPS routes.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.city,
    required this.weekKey,
    required this.distanceM,
    required this.runCount,
    required this.updatedAt,
  });

  final String uid;
  final String displayName;
  final String city;
  final String weekKey;
  final double distanceM;
  final int runCount;
  final DateTime updatedAt;

  String get documentId => '${weekKey}_$uid';

  double get distanceKm => distanceM / 1000.0;

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'N';
    final first = parts.first.substring(0, 1);
    final last = parts.length > 1 && parts.last.isNotEmpty
        ? parts.last.substring(0, 1)
        : '';
    return '$first$last'.toUpperCase();
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'displayName': displayName,
    'city': city,
    'weekKey': weekKey,
    'distanceM': distanceM,
    'runCount': runCount,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  static LeaderboardEntry fromMap(Map<String, dynamic> map) => LeaderboardEntry(
    uid: map['uid'] as String? ?? '',
    displayName: map['displayName'] as String? ?? 'Runner',
    city: map['city'] as String? ?? '',
    weekKey: map['weekKey'] as String? ?? '',
    distanceM: (map['distanceM'] as num?)?.toDouble() ?? 0,
    runCount: (map['runCount'] as num?)?.toInt() ?? 0,
    updatedAt:
        DateTime.tryParse(map['updatedAt'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
  );
}
