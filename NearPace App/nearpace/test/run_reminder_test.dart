import 'package:flutter_test/flutter_test.dart';
import 'package:nearpace/domain/run_reminder.dart';
import 'package:nearpace/domain/user_profile.dart';

void main() {
  group('RunReminder', () {
    test('defaults to disabled Mon/Wed/Fri at 06:30', () {
      const reminder = RunReminder();
      expect(reminder.enabled, isFalse);
      expect(reminder.isActive, isFalse);
      expect(reminder.sortedWeekdays, [1, 3, 5]);
      expect(reminder.formattedTime, '06:30');
    });

    test(
      'computes next scheduled date later today when before target time',
      () {
        // 2026-11-23 is a Monday.
        final now = DateTime(2026, 11, 23, 5, 45);
        const reminder = RunReminder(
          enabled: true,
          weekdays: {DateTime.monday, DateTime.wednesday},
          hour: 6,
          minute: 30,
        );

        final next = reminder.nextScheduledDate(now);
        expect(next, DateTime(2026, 11, 23, 6, 30));
        expect(reminder.nextSummaryLabel(now), 'Today, 06:30');
      },
    );

    test('skips to next selected weekday when today time has passed', () {
      // 2026-11-23 is Monday 07:00 -> next is Wednesday 06:30.
      final now = DateTime(2026, 11, 23, 7, 0);
      const reminder = RunReminder(
        enabled: true,
        weekdays: {DateTime.monday, DateTime.wednesday},
        hour: 6,
        minute: 30,
      );

      final next = reminder.nextScheduledDate(now);
      expect(next, DateTime(2026, 11, 25, 6, 30));
      expect(reminder.nextSummaryLabel(now), 'Wed, 06:30');
    });

    test('wraps across week boundary when only earlier day is selected', () {
      // 2026-11-21 is Saturday 09:00 -> next Monday is 2026-11-23 06:30.
      final now = DateTime(2026, 11, 21, 9, 0);
      const reminder = RunReminder(
        enabled: true,
        weekdays: {DateTime.monday},
        hour: 6,
        minute: 30,
      );

      final next = reminder.nextScheduledDate(now);
      expect(next, DateTime(2026, 11, 23, 6, 30));
      expect(reminder.nextSummaryLabel(now), 'Mon, 06:30');
    });

    test('returns Tomorrow label when next reminder is next day', () {
      // 2026-11-21 is Saturday 09:00 -> Sunday 07:15 is Tomorrow.
      final now = DateTime(2026, 11, 21, 9, 0);
      const reminder = RunReminder(
        enabled: true,
        weekdays: {DateTime.sunday},
        hour: 7,
        minute: 15,
      );

      expect(reminder.nextSummaryLabel(now), 'Tomorrow, 07:15');
    });

    test('returns null when disabled or no days selected', () {
      final now = DateTime(2026, 11, 21, 9, 0);
      expect(const RunReminder(enabled: false).nextScheduledDate(now), isNull);
      expect(
        const RunReminder(enabled: true, weekdays: {}).nextScheduledDate(now),
        isNull,
      );
    });

    test('uses capitalized Huss, Huss, Huss! meme notification title', () {
      expect(RunReminder.notificationTitle, 'Huss, Huss, Huss! Time to run 🏃');
      for (var day = DateTime.monday; day <= DateTime.sunday; day++) {
        expect(RunReminder.bodyForWeekday(day), isNotEmpty);
      }
      expect(
        RunReminder.bodyForWeekday(DateTime.friday),
        contains('Huss, Huss, Huss!'),
      );
      expect(
        RunReminder.bodyForWeekday(DateTime.saturday),
        contains('Huss, Huss, Huss!'),
      );
    });

    test('round-trips through toMap / fromMap and UserProfile', () {
      const reminder = RunReminder(
        enabled: true,
        weekdays: {DateTime.tuesday, DateTime.thursday, DateTime.sunday},
        hour: 17,
        minute: 45,
      );

      final restored = RunReminder.fromMap(reminder.toMap());
      expect(restored, reminder);

      final profile = UserProfile(
        uid: 'u1',
        email: 'runner@nearpace.app',
        displayName: 'Alief',
        city: 'Makassar',
        showOnLeaderboard: true,
        runReminder: reminder,
        receiveUpdates: false,
      );
      final restoredProfile = UserProfile.fromMap('u1', profile.toMap());
      expect(restoredProfile.runReminder, reminder);
      expect(restoredProfile.receiveUpdates, isFalse);
    });
  });
}
