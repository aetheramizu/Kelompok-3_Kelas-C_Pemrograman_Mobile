import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../state/nearpace_controller.dart' show ForegroundNotice;

/// Top-level background message handler for FCM.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handled automatically by system tray when app is killed or backgrounded.
}

/// Contract for push notification delivery and token management.
abstract interface class PushNotificationService {
  Future<String?> initializeAndGetToken();
  Stream<String> get onTokenRefresh;
  Stream<ForegroundNotice> get foregroundMessages;
  Future<void> subscribeToTopic(String topic);
  Future<void> unsubscribeFromTopic(String topic);
}

/// Firebase Cloud Messaging implementation of [PushNotificationService].
class FcmPushNotificationService implements PushNotificationService {
  FcmPushNotificationService({FirebaseMessaging? messaging})
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;
  final StreamController<ForegroundNotice> _foregroundNoticeController =
      StreamController<ForegroundNotice>.broadcast();

  StreamSubscription<RemoteMessage>? _onMessageSubscription;

  @override
  // ignore: deprecated_member_use
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<ForegroundNotice> get foregroundMessages =>
      _foregroundNoticeController.stream;

  @override
  Future<String?> initializeAndGetToken() async {
    try {
      // Register background handler.
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Request runtime notification permission (Android 13+ / iOS).
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return null;
      }

      // Listen to foreground messages and emit ForegroundNotice.
      _onMessageSubscription?.cancel();
      _onMessageSubscription = FirebaseMessaging.onMessage.listen((message) {
        final title =
            message.notification?.title ??
            message.data['title']?.toString() ??
            'NearPace update';
        final body =
            message.notification?.body ??
            message.data['body']?.toString() ??
            '';
        final notice = ForegroundNotice(
          title: title,
          body: body,
          receivedAt: DateTime.now(),
          topic: message.from ?? 'nearpace_updates',
        );
        _foregroundNoticeController.add(notice);
      });

      // Get initial device FCM token.
      // ignore: deprecated_member_use
      final token = await _messaging.getToken();
      return token;
    } catch (_) {
      // Degrade gracefully if Google Play Services is missing or unconfigured.
      return null;
    }
  }

  @override
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
    } catch (_) {
      // Ignore failure on devices without Play Services.
    }
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
    } catch (_) {
      // Ignore failure.
    }
  }

  void dispose() {
    _onMessageSubscription?.cancel();
    _foregroundNoticeController.close();
  }
}

/// No-op implementation of [PushNotificationService] for tests and local preview.
class NoopPushNotificationService implements PushNotificationService {
  NoopPushNotificationService();

  final StreamController<String> _tokenRefreshController =
      StreamController<String>.broadcast();
  final StreamController<ForegroundNotice> _noticeController =
      StreamController<ForegroundNotice>.broadcast();

  @override
  Future<String?> initializeAndGetToken() async => null;

  @override
  Stream<String> get onTokenRefresh => _tokenRefreshController.stream;

  @override
  Stream<ForegroundNotice> get foregroundMessages => _noticeController.stream;

  @override
  Future<void> subscribeToTopic(String topic) async {}

  @override
  Future<void> unsubscribeFromTopic(String topic) async {}

  void emitNotice(ForegroundNotice notice) {
    if (!_noticeController.isClosed) {
      _noticeController.add(notice);
    }
  }

  void dispose() {
    _tokenRefreshController.close();
    _noticeController.close();
  }
}
