// notification_service.dart
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'medcare_reminders',
      'แจ้งเตือนยา',
      channelDescription: 'แจ้งเตือนเมื่อถึงเวลากินยา',
      importance: Importance.max,
      priority: Priority.high,
    ),
  );

  static Future<void> init() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Bangkok'));

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);

    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  // hash คงที่ทุกครั้งที่รัน (FNV-1a) ใช้แปลง docId เป็นเลข id ของแจ้งเตือน
  static int _idFromDocId(String docId) {
    int hash = 0x811C9DC5;
    for (int unit in docId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return hash;
  }

  static Future<void> schedule({
    required String docId,
    required String title,
    required String body,
    required DateTime time,
  }) async {
    if (!time.isAfter(DateTime.now())) return;

    int id = _idFromDocId(docId);
    tz.TZDateTime date = tz.TZDateTime.from(time, tz.local);

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        date,
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } on PlatformException {
      // ไม่ได้รับสิทธิ์ตั้งเวลาแบบตรงเป๊ะ ใช้แบบประมาณเวลาแทน
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        date,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  static Future<void> cancel(String docId) async {
    await _plugin.cancel(_idFromDocId(docId));
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}