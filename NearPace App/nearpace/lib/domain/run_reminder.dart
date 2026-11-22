/// User-configurable weekly running reminder schedule.
///
/// Weekdays use ISO-8601 numbering matching [DateTime.weekday]:
/// Monday = 1 through Sunday = 7.
class RunReminder {
  const RunReminder({
    this.enabled = false,
    this.weekdays = defaultWeekdays,
    this.hour = defaultHour,
    this.minute = defaultMinute,
  });

  static const Set<int> defaultWeekdays = {
    DateTime.monday,
    DateTime.wednesday,
    DateTime.friday,
  };
  static const int defaultHour = 6;
  static const int defaultMinute = 30;

  static const String notificationTitle = 'Huss, Huss, Huss! Time to run 🏃';
  static const String testReminderBody =
      'In this town, everybody\'s chilling except you. '
      'Lace up — Huss, Huss, Huss!';

  final bool enabled;
  final Set<int> weekdays;
  final int hour;
  final int minute;

  List<int> get sortedWeekdays {
    final valid = weekdays.where((d) => d >= 1 && d <= 7).toList()..sort();
    return List.unmodifiable(valid);
  }

  /// True when the reminder is turned on and at least one weekday is selected.
  bool get isActive => enabled && sortedWeekdays.isNotEmpty;

  /// Zero-padded 24-hour time string, e.g. `06:30`.
  String get formattedTime {
    final hh = hour.clamp(0, 23).toString().padLeft(2, '0');
    final mm = minute.clamp(0, 59).toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  /// Rotating weekday meme copy for scheduled reminder notifications.
  static String bodyForWeekday(int weekday) => switch (weekday) {
    DateTime.monday =>
      'In this town, everybody\'s still sleeping except you. '
          'Lace up and start hussing.',
    DateTime.tuesday =>
      'Huss Valley called. Your pace isn\'t going to improve itself.',
    DateTime.wednesday =>
      'Midweek check-in: everybody\'s chilling, you\'re hussing. Let\'s go!',
    DateTime.thursday =>
      'Fastest husser on the leaderboard won\'t beat themselves. Time to move!',
    DateTime.friday =>
      'In this town, everybody goes out partying except you. '
          'Huss, Huss, Huss!',
    DateTime.saturday =>
      'Weekend grind unlocked. Shoes on, GPS ready — Huss, Huss, Huss!',
    DateTime.sunday =>
      'One last run before the weekly board resets. Don\'t stop hussing now!',
    _ => testReminderBody,
  };

  /// Computes the next scheduled local [DateTime] strictly after [now],
  /// or `null` when reminders are disabled or no weekdays are selected.
  DateTime? nextScheduledDate(DateTime now) {
    if (!isActive) return null;
    final local = now.toLocal();
    final safeHour = hour.clamp(0, 23);
    final safeMinute = minute.clamp(0, 59);
    final activeDays = sortedWeekdays.toSet();

    for (var offset = 0; offset <= 7; offset++) {
      final base = DateTime(
        local.year,
        local.month,
        local.day + offset,
        safeHour,
        safeMinute,
      );
      if (activeDays.contains(base.weekday) && base.isAfter(local)) {
        return base;
      }
    }
    return null;
  }

  /// Short human-readable summary of the next reminder, e.g. `Mon, 06:30`
  /// or `Today, 18:00`.
  String? nextSummaryLabel(DateTime now) {
    final next = nextScheduledDate(now);
    if (next == null) return null;
    final localNow = now.toLocal();
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    final targetDay = DateTime(next.year, next.month, next.day);
    final diffDays = targetDay.difference(today).inDays;

    const weekdaysShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayLabel = switch (diffDays) {
      0 => 'Today',
      1 => 'Tomorrow',
      _ => weekdaysShort[(next.weekday - 1).clamp(0, 6)],
    };
    return '$dayLabel, $formattedTime';
  }

  RunReminder copyWith({
    bool? enabled,
    Set<int>? weekdays,
    int? hour,
    int? minute,
  }) => RunReminder(
    enabled: enabled ?? this.enabled,
    weekdays: weekdays ?? this.weekdays,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
  );

  Map<String, dynamic> toMap() => {
    'enabled': enabled,
    'weekdays': sortedWeekdays,
    'hour': hour.clamp(0, 23),
    'minute': minute.clamp(0, 59),
  };

  static RunReminder fromMap(Map<String, dynamic>? map) {
    if (map == null) return const RunReminder();
    final rawDays = map['weekdays'] as List<dynamic>?;
    final parsedDays = rawDays == null
        ? defaultWeekdays
        : rawDays
              .whereType<num>()
              .map((n) => n.toInt())
              .where((d) => d >= 1 && d <= 7)
              .toSet();
    return RunReminder(
      enabled: map['enabled'] as bool? ?? false,
      weekdays: parsedDays.isEmpty && rawDays == null
          ? defaultWeekdays
          : parsedDays,
      hour: (map['hour'] as num?)?.toInt().clamp(0, 23) ?? defaultHour,
      minute: (map['minute'] as num?)?.toInt().clamp(0, 59) ?? defaultMinute,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RunReminder) return false;
    final a = sortedWeekdays;
    final b = other.sortedWeekdays;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return enabled == other.enabled &&
        hour == other.hour &&
        minute == other.minute;
  }

  @override
  int get hashCode =>
      Object.hash(enabled, hour, minute, Object.hashAll(sortedWeekdays));
}
