import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _sleepReminderId  = 1;
  static const _routineReminderId = 2;

  static Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    final tzName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzName));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: iOS),
    );
    _initialized = true;
  }

  // Uyku başladığında 3 saat sonra bildirim planla
  static Future<void> scheduleSleepReminder() async {
    await _plugin.zonedSchedule(
      _sleepReminderId,
      'Tatlı Rüyalar',
      'Bebek 3 saattir uyuyor — kontrol etmek ister misiniz?',
      tz.TZDateTime.now(tz.local).add(const Duration(hours: 3)),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'sleep_reminder',
          'Uyku Hatırlatıcısı',
          channelDescription: 'Uzun uyku uyarıları',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelSleepReminder() async {
    await _plugin.cancel(_sleepReminderId);
  }

  // Rutin başladığında anlık bildirim
  static Future<void> showRoutineReminder(String routineName) async {
    await _plugin.show(
      _routineReminderId,
      'Rutin Zamanı 🌙',
      '"$routineName" rutinini başlatmayı unutmayın.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'routine_reminder',
          'Rutin Hatırlatıcısı',
          channelDescription: 'Uyku rutini bildirimleri',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, sound: true);
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }
}
