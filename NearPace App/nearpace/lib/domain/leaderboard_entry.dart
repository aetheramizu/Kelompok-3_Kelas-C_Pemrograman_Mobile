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
    this.avatarId,
  });

  final String uid;
  final String displayName;
  final String city;
  final String weekKey;
  final double distanceM;
  final int runCount;
  final DateTime updatedAt;
  final String? avatarId;

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

  LeaderboardEntry copyWith({
    String? uid,
    String? displayName,
    String? city,
    String? weekKey,
    double? distanceM,
    int? runCount,
    DateTime? updatedAt,
    String? avatarId,
  }) => LeaderboardEntry(
    uid: uid ?? this.uid,
    displayName: displayName ?? this.displayName,
    city: city ?? this.city,
    weekKey: weekKey ?? this.weekKey,
    distanceM: distanceM ?? this.distanceM,
    runCount: runCount ?? this.runCount,
    updatedAt: updatedAt ?? this.updatedAt,
    avatarId: avatarId ?? this.avatarId,
  );

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'displayName': displayName,
    'city': city,
    'weekKey': weekKey,
    'distanceM': distanceM,
    'runCount': runCount,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (avatarId != null) 'avatarId': avatarId,
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
    avatarId: map['avatarId'] as String?,
  );
}
