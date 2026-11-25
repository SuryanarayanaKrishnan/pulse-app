import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local reminders for document dates and SIPs. Scheduled on the phone; no
/// push service and no server involved.
abstract class Reminders {
  Future<void> init();

  /// Asks the OS for permission; true when allowed (or not needed).
  Future<bool> requestPermission();
  Future<void> schedule({required int id, required String title, required String body, required DateTime at});
  Future<void> cancel(int id);
}

class NoopReminders implements Reminders {
  const NoopReminders();
  @override
  Future<void> init() async {}
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<void> schedule({required int id, required String title, required String body, required DateTime at}) async {}
  @override
  Future<void> cancel(int id) async {}
}

class LocalNotificationReminders implements Reminders {
  LocalNotificationReminders([FlutterLocalNotificationsPlugin? plugin]) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();
  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  @override
  Future<void> init() async {
    if (_ready || kIsWeb) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
  }

  @override
  Future<void> schedule({required int id, required String title, required String body, required DateTime at}) async {
    if (kIsWeb) return;
    await init();
    // The instant is what matters, so schedule in UTC and avoid needing the
    // device's zone name.
    final when = tz.TZDateTime.from(at.toUtc(), tz.UTC);
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: when,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'pulse_reminders',
          'Reminders',
          channelDescription: 'Document dates and fund SIPs',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancel(int id) async {
    if (kIsWeb) return;
    await init();
    await _plugin.cancel(id: id);
  }
}

/// Test double that remembers what was scheduled.
class RecordingReminders implements Reminders {
  final Map<int, (String, String, DateTime)> scheduled = {};
  bool allowed = true;
  @override
  Future<void> init() async {}
  @override
  Future<bool> requestPermission() async => allowed;
  @override
  Future<void> schedule({required int id, required String title, required String body, required DateTime at}) async =>
      scheduled[id] = (title, body, at);
  @override
  Future<void> cancel(int id) async => scheduled.remove(id);
}
