// ignore_for_file: avoid_print

import 'dart:isolate';

import 'package:encrypted_shared_preferences/encrypted_shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:js_flutter/repository/BgReadingRepository.dart';
import 'package:js_flutter/entity/BgReadingEntity.dart';
import 'package:js_flutter/firebase_options.dart';
import 'package:js_flutter/services/NotificationService.dart';
import 'package:js_flutter/services/apiController.dart';

class MyTaskHandler extends TaskHandler {
  final EncryptedSharedPreferences encryptedSharedPreferences =
      EncryptedSharedPreferences();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  SendPort? _sendPort;
  int _eventCount = 0;
  BgReadingRepository? _bgRepo;
  ApiController? _apiController;
  String? id;
  String? pwd;
  DateTime? lastReadingTime;

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _apiController = ApiController();
    _bgRepo = BgReadingRepository();
    _sendPort = sendPort;
    await encryptedSharedPreferences.getString('id').then((String _value) {
      id = _value;
    });
    await encryptedSharedPreferences.getString('pwd').then((String _value) {
      pwd = _value;
    });
  }

  @override
  Future<void> onEvent(DateTime timestamp, SendPort? sendPort) async {
    FlutterForegroundTask.updateService(
      notificationTitle: 'DIA App',
      notificationText: 'Aplikace DIA běží v pozadí.',
    );

    // Send data to the main isolate.
    sendPort?.send(_eventCount);

    try {
      _apiController!.getBG(id!, pwd!).then((value) {
        if (value != null) {
          if (lastReadingTime != null &&
              value.time.difference(lastReadingTime!).inSeconds > 310) {
            var difference = value.time.difference(lastReadingTime!).inSeconds;
            var numOfMissedReadings = (difference / 300).ceil();
            _apiController!
                .getXLastBGs(id!, pwd!, numOfMissedReadings)
                .then((value) {
              if (value != null) {
                for (var element in value) {
                  _bgRepo!.create(BgReadingEntity(
                      trend: element.trend,
                      time: element.time,
                      mmol: element.mmol));
                }
              }
            });
            lastReadingTime = value.time;
          }
          if (lastReadingTime == null || lastReadingTime != value.time) {
            lastReadingTime = value.time;
            if (value.mmol >= 8.5) {
              NotificationService.showNotification(
                  title: "DIA App",
                  body: "Vaše poslední nameřená hodnota byla příliš vysoká!",
                  fln: flutterLocalNotificationsPlugin);
            } else if (value.mmol <= 4) {
              NotificationService.showNotification(
                  title: "DIA App",
                  body: "Vaše poslední nameřená hodnota byla příliš nízká!",
                  fln: flutterLocalNotificationsPlugin);
            }
            switch (value.trend) {
              case "↑↑":
                NotificationService.showNotification(
                    title: "DIA App",
                    body: "Pozor! Vaše glykémie velmi rychle stoupá!",
                    fln: flutterLocalNotificationsPlugin);
                break;
              case "↓↓":
                NotificationService.showNotification(
                    title: "DIA App",
                    body: "Pozor! Vaše glykémie velmi rychle klesá!",
                    fln: flutterLocalNotificationsPlugin);
                break;
              default:
            }
            _bgRepo!.create(BgReadingEntity(
                trend: value.trend, time: value.time, mmol: value.mmol));
          }
        }
      });
    } on Exception catch (e) {
      print(e);
    }

    _eventCount++;
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    // You can use the clearAllData function to clear all the stored data.
    await FlutterForegroundTask.clearAllData();
  }

  @override
  void onButtonPressed(String id) {
    // Called when the notification button on the Android platform is pressed.
    print('onButtonPressed >> $id');
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
    _sendPort?.send('onNotificationPressed');
  }
}

class ForegroundService {
  static ReceivePort? _receivePort;

  void initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'foreground_service_notification',
        channelName: 'Trvalé oznámení',
        channelDescription:
            'Tato notifikace se zobrazuje pokud aplikace běží na pozadí.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher_icon',
        ),
        enableVibration: false,
        playSound: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 1000 * 60 * 5,
        isOnceEvent: false,
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<bool> startForegroundTask({required Function startCallback}) async {
    if (!await FlutterForegroundTask.canDrawOverlays) {
      final isGranted =
          await FlutterForegroundTask.openSystemAlertWindowSettings();
      if (!isGranted) {
        print('SYSTEM_ALERT_WINDOW permission denied!');
        return false;
      }
    }

    bool reqResult;
    if (await FlutterForegroundTask.isRunningService) {
      reqResult = await FlutterForegroundTask.restartService();
    } else {
      reqResult = await FlutterForegroundTask.startService(
        notificationTitle: 'Foreground Service is running',
        notificationText: 'Tap to return to the app',
        callback: startCallback,
      );
    }

    ReceivePort? receivePort;
    if (reqResult) {
      receivePort = await FlutterForegroundTask.receivePort;
    }

    return registerReceivePort(receivePort);
  }

  Future<bool> stopForegroundTask() async {
    return await FlutterForegroundTask.stopService();
  }

  bool registerReceivePort(ReceivePort? receivePort) {
    closeReceivePort();

    if (receivePort != null) {
      _receivePort = receivePort;
      _receivePort?.listen((message) {});

      return true;
    }

    return false;
  }

  void closeReceivePort() {
    _receivePort?.close();
    _receivePort = null;
  }
}
