import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling a background message: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription? _foregroundMessageSubscription;
  String? _fcmToken;

  Future<void> initialize() async {
    tz_data.initializeTimeZones();

    await _requestPermission();

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await _initializeLocalNotifications();

    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );

    _fcmToken = await _messaging.getToken();
    debugPrint('[NOTIF] FCM Token: $_fcmToken');

    _messaging.onTokenRefresh.listen((token) {
      _fcmToken = token;
      debugPrint('[NOTIF] FCM Token refreshed: $token');
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
  }

  Future<String?> getFreshToken() async {
    _fcmToken = await _messaging.getToken();
    return _fcmToken;
  }

  Future<bool> ensurePermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  Future<void> _requestPermission() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('User granted permission: ${settings.authorizationStatus}');
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  void Function(String? payload)? onAction;

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    final payload = response.payload;
    final actionId = response.actionId;
    if (payload != null && actionId != null && actionId.isNotEmpty) {
      onAction?.call('itemId=$payload&action=$actionId');
    } else {
      onAction?.call(payload);
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('[NOTIF] Got a message whilst in the foreground!');
    debugPrint('[NOTIF] Message data: ${message.data}');
    debugPrint('[NOTIF] Message notification: ${message.notification}');
    debugPrint('[NOTIF] Notification title: ${message.notification?.title}');
    debugPrint('[NOTIF] Notification body: ${message.notification?.body}');

    if (message.notification != null) {
      await _showLocalNotification(message);
    } else {
      debugPrint('[NOTIF] No notification payload in message, skipping local notification');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    debugPrint('[NOTIF] Showing local notification: ${notification.title} - ${notification.body}');

    final actions = message.data['type'] == 'digest'
        ? [const AndroidNotificationAction('open_unread_list', 'Open Unread')]
        : [
            const AndroidNotificationAction('mark_read', 'Mark Read'),
            const AndroidNotificationAction('snooze_30', 'Snooze 30m'),
            const AndroidNotificationAction('lower_priority', 'Lower Priority'),
          ];

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'rem_channel',
          'REM Notifications',
          channelDescription: 'Notifications for REM app',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          actions: actions,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _localNotifications.show(
        message.hashCode,
        notification.title,
        notification.body,
        platformDetails,
        payload: message.data['itemId'],
      );
      debugPrint('[NOTIF] Local notification shown successfully');
    } catch (e) {
      debugPrint('[NOTIF] Error showing local notification: $e');
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('Message opened app: ${message.data}');
  }

  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    await _localNotifications.cancel(0);

    await _localNotifications.zonedSchedule(
      0,
      'Daily Reminder',
      'Time to catch up on your saved items!',
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder_channel',
          'Daily Reminders',
          channelDescription: 'Daily reminder to check your REM vault',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    debugPrint('Scheduled daily reminder for $hour:$minute');
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  Future<void> snoozeNotification({int minutes = 30, String? itemId}) async {
    final id = itemId != null
        ? itemId.hashCode
        : DateTime.now().millisecondsSinceEpoch % 100000;

    await _localNotifications.zonedSchedule(
      id,
      'Reminder',
      'Don\'t forget to check this item!',
      tz.TZDateTime.now(tz.local).add(Duration(minutes: minutes)),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'snooze_channel',
          'Snoozed Reminders',
          channelDescription: 'Snoozed item reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: itemId,
    );

    debugPrint('Snoozed notification for $minutes minutes');
  }

  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  Future<void> dispose() async {
    _foregroundMessageSubscription?.cancel();
  }

  String? get fcmToken => _fcmToken;



  Future<void> registerTokenWithBackend(
    Future<dynamic> Function(String, String) registerFn,
  ) async {
    final token = await getFreshToken();
    if (token != null) {
      try {
        await registerFn(token, 'android');
      } catch (e) {
        debugPrint('Failed to register push token: $e');
      }
    }
  }
}
