import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static NotificationAppLaunchDetails? notificationAppLaunchDetails;

  static Future<void> init(
      FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin) async {
    var androidInitialize =
        const AndroidInitializationSettings('mipmap/ic_launcher_icon');
    var iOSInitialize = const DarwinInitializationSettings();
    var initializationSettings =
        InitializationSettings(android: androidInitialize, iOS: iOSInitialize);
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );
  }

  static Future showNotification(
      {var id = 0,
      required String title,
      required String body,
      var payload,
      required FlutterLocalNotificationsPlugin fln}) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails('default_notification_channel', 'Ostatní',
            channelDescription: 'Základní kanál pro notifikace.',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true);
    const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails, iOS: DarwinNotificationDetails());
    await fln.show(
      id++,
      title,
      body,
      notificationDetails,
    );
  }

  void cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  void cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
