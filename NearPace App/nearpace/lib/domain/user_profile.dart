import 'run_reminder.dart';

/// Private user profile stored at `users/{uid}`.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.city,
    required this.showOnLeaderboard,
    this.fcmToken,
    this.runReminder = const RunReminder(),
    this.receiveUpdates = true,
  });

  final String uid;
  final String email;
  final String displayName;
  final String city;
  final bool showOnLeaderboard;
  final String? fcmToken;
  final RunReminder runReminder;
  final bool receiveUpdates;

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'N';
    final first = parts.first.substring(0, 1);
    final last = parts.length > 1 && parts.last.isNotEmpty
        ? parts.last.substring(0, 1)
        : '';
    return '$first$last'.toUpperCase();
  }

  UserProfile copyWith({
    String? displayName,
    String? city,
    bool? showOnLeaderboard,
    String? fcmToken,
    RunReminder? runReminder,
    bool? receiveUpdates,
  }) => UserProfile(
    uid: uid,
    email: email,
    displayName: displayName ?? this.displayName,
    city: city ?? this.city,
    showOnLeaderboard: showOnLeaderboard ?? this.showOnLeaderboard,
    fcmToken: fcmToken ?? this.fcmToken,
    runReminder: runReminder ?? this.runReminder,
    receiveUpdates: receiveUpdates ?? this.receiveUpdates,
  );

  Map<String, dynamic> toMap() => {
    'email': email,
    'displayName': displayName,
    'city': city,
    'showOnLeaderboard': showOnLeaderboard,
    if (fcmToken != null) 'fcmToken': fcmToken,
    'runReminder': runReminder.toMap(),
    'receiveUpdates': receiveUpdates,
  };

  static UserProfile fromMap(String uid, Map<String, dynamic> map) =>
      UserProfile(
        uid: uid,
        email: map['email'] as String? ?? '',
        displayName: map['displayName'] as String? ?? 'Runner',
        city: map['city'] as String? ?? '',
        showOnLeaderboard: map['showOnLeaderboard'] as bool? ?? false,
        fcmToken: map['fcmToken'] as String?,
        runReminder: RunReminder.fromMap(
          map['runReminder'] is Map
              ? Map<String, dynamic>.from(map['runReminder'] as Map)
              : null,
        ),
        receiveUpdates: map['receiveUpdates'] as bool? ?? true,
      );
}
