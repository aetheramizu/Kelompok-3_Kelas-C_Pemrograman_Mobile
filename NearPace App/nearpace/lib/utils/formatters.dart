/// Formatting utilities for running metrics, dates, and ISO week keys.
class NearPaceFormatters {
  const NearPaceFormatters._();

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const _weekdaysShort = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  /// Formats metres as kilometres with two decimals, e.g. `5.24`.
  static String distanceKmValue(double meters, {int decimals = 2}) {
    final km = meters < 0 ? 0.0 : meters / 1000.0;
    return km.toStringAsFixed(decimals);
  }

  /// Formats metres as kilometres with unit, e.g. `5.24 km`.
  static String distanceKm(double meters, {int decimals = 2}) {
    return '${distanceKmValue(meters, decimals: decimals)} km';
  }

  /// Formats a duration as `MM:SS` or `H:MM:SS` for tabular display.
  static String durationClock(Duration duration) {
    final safe = duration.isNegative ? Duration.zero : duration;
    final hours = safe.inHours;
    final minutes = safe.inMinutes.remainder(60);
    final seconds = safe.inSeconds.remainder(60);
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$mm:$ss';
    }
    return '$mm:$ss';
  }

  /// Formats a compact total duration, e.g. `1h 36m` or `28m`.
  static String durationCompact(Duration duration) {
    final safe = duration.isNegative ? Duration.zero : duration;
    final hours = safe.inHours;
    final minutes = safe.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    if (minutes > 0) {
      return '${minutes}m';
    }
    return '${safe.inSeconds}s';
  }

  /// Formats pace in seconds per km as `M:SS`, or `--:--` when unavailable.
  static String paceValue(double? secPerKm) {
    if (secPerKm == null ||
        secPerKm.isNaN ||
        secPerKm.isInfinite ||
        secPerKm <= 0) {
      return '--:--';
    }
    final totalSeconds = secPerKm.round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Formats pace with `/km` suffix, or `--:-- /km` when unavailable.
  static String paceWithUnit(double? secPerKm) => '${paceValue(secPerKm)} /km';

  /// Returns the ISO week start date (`yyyy-MM-dd`, Monday) in local time,
  /// matching the MVP leaderboard `weekKey` contract.
  static String isoWeekKey(DateTime date) {
    final local = date.toLocal();
    final monday = DateTime(
      local.year,
      local.month,
      local.day,
    ).subtract(Duration(days: local.weekday - DateTime.monday));
    final y = monday.year.toString().padLeft(4, '0');
    final m = monday.month.toString().padLeft(2, '0');
    final d = monday.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Returns the Monday DateTime for the ISO week containing [date].
  static DateTime startOfIsoWeek(DateTime date) {
    final local = date.toLocal();
    return DateTime(
      local.year,
      local.month,
      local.day,
    ).subtract(Duration(days: local.weekday - DateTime.monday));
  }

  /// Human-readable week range label, e.g. `Nov 16 – Nov 22`.
  static String weekRangeLabel(DateTime date) {
    final start = startOfIsoWeek(date);
    final end = start.add(const Duration(days: 6));
    return '${_months[start.month - 1]} ${start.day} – '
        '${_months[end.month - 1]} ${end.day}';
  }

  /// Human-readable header date, e.g. `Sat, Nov 21`.
  static String shortHeaderDate(DateTime date) {
    final local = date.toLocal();
    return '${_weekdaysShort[local.weekday - 1]}, '
        '${_months[local.month - 1]} ${local.day}';
  }

  /// Formats a run timestamp, e.g. `Nov 21, 06:15`.
  static String activityTimestamp(DateTime date) {
    final local = date.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${_months[local.month - 1]} ${local.day}, $hh:$mm';
  }

  /// Descriptive time-of-day title for a run, e.g. `Morning run`.
  static String runSessionTitle(DateTime startedAt) {
    final hour = startedAt.toLocal().hour;
    if (hour < 11) return 'Morning run';
    if (hour < 15) return 'Midday run';
    if (hour < 19) return 'Afternoon run';
    return 'Evening run';
  }

  /// Weekday single-letter label for Monday (1) through Sunday (7).
  static String weekdayInitial(int weekday) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final index = (weekday - 1).clamp(0, 6);
    return labels[index];
  }
}
