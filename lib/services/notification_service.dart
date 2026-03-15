import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Returns true if this platform supports flutter_local_notifications scheduling.
bool get _isMobilePlatform =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (!_isMobilePlatform) return; // Notifications unsupported on Windows/desktop
    tz.initializeTimeZones();
    
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
      },
    );

    if (Platform.isAndroid) {
      await _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    if (!_isMobilePlatform) {
      // Scheduling notifications is not supported on Windows/desktop.
      debugPrint('MOCK: Would schedule notification "$title" at $scheduledTime');
      return;
    }
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'medicep_reminders',
          'Medication Reminders',
          channelDescription: 'Notifications for scheduled medication doses',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily at this time
    );
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }
}
