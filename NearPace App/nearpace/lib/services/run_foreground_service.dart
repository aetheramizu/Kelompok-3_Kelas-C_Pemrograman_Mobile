import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Top-level callback entrypoint for the background task isolate.
@pragma('vm:entry-point')
void nearPaceForegroundTaskCallback() {
  FlutterForegroundTask.setTaskHandler(NearPaceTaskHandler());
}

/// Task handler receiving Android notification button events in the task isolate.
class NearPaceTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationButtonPressed(String id) {
    FlutterForegroundTask.sendDataToMain(id);
  }
}

/// Contract for foreground service lifecycle and sticky notification updates.
abstract interface class RunForegroundService {
  Future<void> initialize();
  Future<void> start({
    required String title,
    required String text,
    required bool isPaused,
  });
  Future<void> update({
    required String title,
    required String text,
    required bool isPaused,
  });
  Future<void> stop();
  void setActionListener(void Function(String action) onAction);
}

/// Foreground service implementation backed by `flutter_foreground_task`.
class FlutterForegroundRunService implements RunForegroundService {
  FlutterForegroundRunService();

  static const _channelId = 'nearpace_run_tracking';
  static const _channelName = 'Active Run Tracking';
  static const _channelDesc =
      'Sticky notification keeping your GPS run session active.';

  bool _initialized = false;
  void Function(String action)? _actionListener;

  List<NotificationButton> _buttonsForState(bool isPaused) {
    if (isPaused) {
      return const [
        NotificationButton(id: 'continue', text: 'Continue'),
        NotificationButton(id: 'stop', text: 'Stop'),
      ];
    }
    return const [
      NotificationButton(id: 'pause', text: 'Pause'),
      NotificationButton(id: 'stop', text: 'Stop'),
    ];
  }

  @override
  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    try {
      FlutterForegroundTask.initCommunicationPort();
      FlutterForegroundTask.addTaskDataCallback((data) {
        if (data is String && _actionListener != null) {
          _actionListener!(data);
        }
      });

      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: _channelId,
          channelName: _channelName,
          channelDescription: _channelDesc,
          channelImportance: NotificationChannelImportance.HIGH,
          priority: NotificationPriority.HIGH,
          onlyAlertOnce: true,
          showWhen: true,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: false,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(5000),
          autoRunOnBoot: false,
          allowWakeLock: true,
          allowWifiLock: true,
        ),
      );
      _initialized = true;
    } catch (_) {
      // Degrade gracefully on mock/headless test hosts
    }
  }

  @override
  Future<void> start({
    required String title,
    required String text,
    required bool isPaused,
  }) async {
    if (kIsWeb) return;
    await initialize();
    try {
      final buttons = _buttonsForState(isPaused);
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: text,
          notificationButtons: buttons,
        );
      } else {
        await FlutterForegroundTask.startService(
          serviceId: 2001,
          serviceTypes: [ForegroundServiceTypes.location],
          notificationTitle: title,
          notificationText: text,
          notificationButtons: buttons,
          callback: nearPaceForegroundTaskCallback,
        );
      }
    } catch (_) {
      // Degrade gracefully if foreground service cannot start
    }
  }

  @override
  Future<void> update({
    required String title,
    required String text,
    required bool isPaused,
  }) async {
    if (kIsWeb) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: text,
          notificationButtons: _buttonsForState(isPaused),
        );
      }
    } catch (_) {
      // Degrade gracefully
    }
  }

  @override
  Future<void> stop() async {
    if (kIsWeb) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {
      // Degrade gracefully
    }
  }

  @override
  void setActionListener(void Function(String action) onAction) {
    _actionListener = onAction;
  }
}

/// No-op fallback implementation of [RunForegroundService] for tests and web.
class NoopRunForegroundService implements RunForegroundService {
  void Function(String action)? _actionListener;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> start({
    required String title,
    required String text,
    required bool isPaused,
  }) async {}

  @override
  Future<void> update({
    required String title,
    required String text,
    required bool isPaused,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  void setActionListener(void Function(String action) onAction) {
    _actionListener = onAction;
  }

  void simulateAction(String action) {
    _actionListener?.call(action);
  }
}
