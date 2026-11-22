import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/run_reminder.dart';

/// Contract for scheduling local recurring running reminders.
abstract interface class RunReminderService {
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<void> syncSchedule(RunReminder reminder);
  Future<void> sendTestReminder();
  Future<void> cancelAll();
}

/// Local scheduled notification implementation backed by
/// `flutter_local_notifications` and device timezone data.
class LocalRunReminderService implements RunReminderService {
  LocalRunReminderService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'nearpace_run_reminders';
  static const _channelName = 'Run reminders';
  static const _channelDescription =
      'Scheduled running reminders to keep your pace on track.';
  static const _weekdayIdBase = 1000;
  static const _testNotificationId = 1099;

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  NotificationDetails get _notificationDetails => const NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  @override
  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    try {
      tz_data.initializeTimeZones();
      try {
        final timezoneInfo = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
      } catch (_) {
        // Keep default local timezone fallback if platform lookup fails.
      }

      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(settings: initSettings);
      _initialized = true;
    } catch (_) {
      // Degrade gracefully on unsupported desktop or headless test hosts.
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    await initialize();
    if (!_initialized) return false;

    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        return granted ?? true;
      }

      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        final granted = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? true;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> syncSchedule(RunReminder reminder) async {
    if (kIsWeb) return;
    await initialize();
    if (!_initialized) return;

    await cancelAll();
    if (!reminder.isActive) return;

    final allowed = await requestPermission();
    if (!allowed) return;

    final now = tz.TZDateTime.now(tz.local);
    final safeHour = reminder.hour.clamp(0, 23);
    final safeMinute = reminder.minute.clamp(0, 59);

    for (final weekday in reminder.sortedWeekdays) {
      final scheduled = _nextInstanceOfWeekdayTime(
        now: now,
        weekday: weekday,
        hour: safeHour,
        minute: safeMinute,
      );
      try {
        await _plugin.zonedSchedule(
          id: _weekdayIdBase + weekday,
          title: RunReminder.notificationTitle,
          body: RunReminder.bodyForWeekday(weekday),
          scheduledDate: scheduled,
          notificationDetails: _notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: 'run_reminder_$weekday',
        );
      } catch (_) {
        // Ignore platform scheduling errors so UI toggles never crash.
      }
    }
  }

  @override
  Future<void> sendTestReminder() async {
    if (kIsWeb) return;
    await initialize();
    if (!_initialized) return;

    final allowed = await requestPermission();
    if (!allowed) return;

    try {
      await _plugin.show(
        id: _testNotificationId,
        title: RunReminder.notificationTitle,
        body: RunReminder.testReminderBody,
        notificationDetails: _notificationDetails,
        payload: 'run_reminder_test',
      );
    } catch (_) {
      // Ignore if notifications are unavailable on this host.
    }
  }

  @override
  Future<void> cancelAll() async {
    if (kIsWeb || !_initialized) return;
    for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++) {
      try {
        await _plugin.cancel(id: _weekdayIdBase + weekday);
      } catch (_) {}
    }
  }

  tz.TZDateTime _nextInstanceOfWeekdayTime({
    required tz.TZDateTime now,
    required int weekday,
    required int hour,
    required int minute,
  }) {
    var candidate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    while (candidate.weekday != weekday || !candidate.isAfter(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }
}

/// No-op implementation of [RunReminderService] for unit/widget tests and local preview.
class NoopRunReminderService implements RunReminderService {
  NoopRunReminderService();

  RunReminder? lastSyncedReminder;
  int syncCount = 0;
  int testReminderCount = 0;
  int cancelCount = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> syncSchedule(RunReminder reminder) async {
    lastSyncedReminder = reminder;
    syncCount++;
  }

  @override
  Future<void> sendTestReminder() async {
    testReminderCount++;
  }

  @override
  Future<void> cancelAll() async {
    cancelCount++;
  }
}
