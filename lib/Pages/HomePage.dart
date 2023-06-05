// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'dart:async';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:disable_battery_optimization/disable_battery_optimization.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:encrypted_shared_preferences/encrypted_shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:js_flutter/repository/DailyStatsRepository.dart';
import 'package:js_flutter/repository/PointsRepository.dart';
import 'package:js_flutter/entity/DailyStatsEntity.dart';
import 'package:js_flutter/services/ForegroundService.dart';
import 'package:js_flutter/services/NotificationService.dart';
import 'package:js_flutter/utils/DateUtils.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'package:js_flutter/pages/MainPage.dart';
import 'package:js_flutter/dataTypes/bgReading.dart';
import 'package:js_flutter/repository/BgReadingRepository.dart';
import 'package:js_flutter/entity/BgReadingEntity.dart';
import 'package:js_flutter/services/apiController.dart';

const bgReadingTaskKey = "bgReading";
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class HomePage extends StatefulWidget {
  const HomePage(
      {Key? key, required this.controller, required this.startCallback})
      : super(key: key);
  final HomePageController controller;
  final Function startCallback;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  _HomePageState();
  String? displayName;
  String? id;
  String? pwd;
  int dailyGoal = 150;
  Timer? timer;
  Timer? delay;
  List<bool> intervals = [true, false, false];
  int selectedInterval = 6;
  DateTime? pausedAt;
  double streakRowSize = 22;
  double circularSize = 55;
  double mainHeight = 0.78;
  List<BgReading> datasource = [];
  List<BgReading> newDatasource = [];
  final ApiController apiController = ApiController();
  BgReadingRepository bgRepo = BgReadingRepository();
  final PointsRepository pointsRepo = PointsRepository();
  ForegroundService foregroundService = ForegroundService();
  final EncryptedSharedPreferences encryptedSharedPreferences =
      EncryptedSharedPreferences();
  TrackballBehavior? _trackballBehavior;
  Stream<DocumentSnapshot<DailyStatsEntity>>? _pointsStream;
  Stream<QuerySnapshot<BgReadingEntity>>? _bgReadingStream;
  AppLifecycleState? appLifecycleState;
  final GlobalKey _graphKey = GlobalKey();
  List<DailyStatsEntity> dailyStats = [];
  final Map<int, String> weekDays = {
    1: "Po",
    2: "Út",
    3: "St",
    4: "Čt",
    5: "Pá",
    6: "So",
    0: "Ne"
  };

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (pausedAt != null &&
          DateTime.now().difference(pausedAt!).inSeconds > 1800) {
        if (timer != null) timer!.cancel();
        if (delay != null) delay!.cancel();
        setUp();
      }
    }
    if (state == AppLifecycleState.paused) {
      pausedAt = DateTime.now();
    }
  }

  @override
  void initState() {
    super.initState();
    _trackballBehavior = TrackballBehavior(
        enable: true,
        activationMode: ActivationMode.singleTap,
        tooltipSettings: const InteractiveTooltip(
            format: 'point.x : point.y', borderWidth: 0));
    WidgetsBinding.instance.addObserver(this);
    NotificationService.init(flutterLocalNotificationsPlugin);
    widget.controller.setUp = setUp;
    widget.controller.cleanUp = cleanUp;
    widget.controller.setPrefs = setPrefs;
    bgRepo.getController(widget.controller);
    setUp();
    permissions();
    foregroundService.initForegroundTask();
  }

  @override
  void dispose() {
    if (timer != null) timer!.cancel();
    if (delay != null) delay!.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void permissions() async {
    if (!await FlutterForegroundTask.canDrawOverlays) {
      final isGranted =
          await FlutterForegroundTask.openSystemAlertWindowSettings();
      if (!isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Toto povolení je vyžadováno pro správný běh aplikace!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    bool? isBatteryDisabled =
        await DisableBatteryOptimization.isAllBatteryOptimizationDisabled;
    if (isBatteryDisabled != null && !isBatteryDisabled) {
      DisableBatteryOptimization.showDisableBatteryOptimizationSettings();
    }
  }

  void initStreams() {
    _pointsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(displayName)
        .collection("dailyStats")
        .doc(getDate(DateTime.now()))
        .withConverter(
          fromFirestore: DailyStatsEntity.fromFirestore,
          toFirestore: (DailyStatsEntity stats, _) => stats.toFirestore(),
        )
        .snapshots();
    _bgReadingStream = FirebaseFirestore.instance
        .collection("users/$displayName/${getDate(DateTime.now())}")
        .withConverter(
            fromFirestore: BgReadingEntity.fromFirestore,
            toFirestore: (BgReadingEntity value, options) =>
                value.toFirestore())
        .snapshots();
  }

  void cleanUp() {
    encryptedSharedPreferences.clear();
    foregroundService.stopForegroundTask();
    timer?.cancel();
    delay?.cancel();
    pwd = null;
    id = null;
  }

  Future<User?> setUser() async {
    return FirebaseAuth.instance.currentUser;
  }

  Future<void> setPrefs() async {
    await encryptedSharedPreferences.getString('id').then((String _value) {
      setState(() {
        id = _value;
      });
    });
    await encryptedSharedPreferences.getString('pwd').then((String _value) {
      setState(() {
        pwd = _value;
      });
    });

    await encryptedSharedPreferences
        .getString('dailyGoal')
        .then((String _value) {
      if (_value.isNotEmpty) {
        setState(() {
          dailyGoal = int.parse(_value);
        });
      }
    });
  }

  Future<void> setUp() async {
    setUser().then((user) {
      if (user != null) {
        setState(() {
          displayName = user.displayName.toString();
        });
        setPrefs().whenComplete(() async {
          if (id!.isNotEmpty && pwd!.isNotEmpty) {
            initStreams();
            setStreak();
            await apiController.getBG(id!, pwd!).then((value) async {
              if (value != null) {
                apiController.getDataSource(selectedInterval).then((value) {
                  setState(() {
                    datasource = value!;
                  });
                });
                bgRepo.create(BgReadingEntity(
                    trend: value.trend, time: value.time, mmol: value.mmol));
                var now = DateTime.now();
                var difference = 325 - now.difference(value.time).inSeconds;
                if (difference < 0) {
                  difference = ((difference + 325) % 60);
                }

                delay = Timer(Duration(seconds: difference), (() async {
                  await foregroundService.stopForegroundTask();
                  apiController.getBG(id!, pwd!).then((value) {
                    if (value != null) {
                      if (value.mmol >= 8.5) {
                        NotificationService.showNotification(
                            title: "DIA App",
                            body:
                                "Vaše poslední nameřená hodnota byla příliš vysoká!",
                            fln: flutterLocalNotificationsPlugin);
                      } else if (value.mmol <= 4) {
                        NotificationService.showNotification(
                            title: "DIA App",
                            body:
                                "Vaše poslední nameřená hodnota byla příliš nízká!",
                            fln: flutterLocalNotificationsPlugin);
                      }
                      bgRepo.create(BgReadingEntity(
                          trend: value.trend,
                          time: value.time,
                          mmol: value.mmol));
                    }
                    foregroundService.startForegroundTask(
                        startCallback: widget.startCallback);
                  });
                }));
                if (id != null && pwd != null) {
                  DailyStatsRepository().syncReadings(id!, pwd!);
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Chyba serveru, data jsou nedostupná.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            });
          }
        });
      }
    });
  }

  Future<void> setStreak() async {
    List<DailyStatsEntity>? tmpDailyStats =
        await DailyStatsRepository().getMyDailyStatsFor(4);

    if (tmpDailyStats != null && tmpDailyStats.isNotEmpty) {
      tmpDailyStats.removeAt(0);

      setState(() {
        dailyStats = tmpDailyStats.reversed.toList();
      });
    }
  }

  /// Returns the line chart with default datetime axis.
  SfCartesianChart _buildDefaultDateTimeAxisChart() {
    return SfCartesianChart(
      key: _graphKey,
      plotAreaBorderWidth: 0,
      primaryXAxis: DateTimeAxis(
        intervalType: DateTimeIntervalType.hours,
        majorGridLines: const MajorGridLines(width: 0),
        interval: 2,
        dateFormat: DateFormat.Hm(),
        isVisible: true,
        labelPosition: ChartDataLabelPosition.outside,
        labelAlignment: LabelAlignment.start,
        opposedPosition: true,
        placeLabelsNearAxisLine: true,
      ),
      primaryYAxis: NumericAxis(
          minimum: 0,
          maximum: 20,
          interval: 4,
          labelFormat: r'{value}',
          axisLine: const AxisLine(width: 0),
          opposedPosition: true,
          majorGridLines: const MajorGridLines(width: 0),
          majorTickLines: const MajorTickLines(size: 0),
          plotBands: <PlotBand>[
            PlotBand(
                isVisible: true,
                start: 0,
                end: 4,
                color: const Color.fromRGBO(255, 102, 102, 0.1),
                opacity: 0.2),
            PlotBand(
                isVisible: true,
                start: 4,
                end: 8.5,
                color: const Color.fromRGBO(76, 153, 0, 0.1),
                opacity: 0.2),
            PlotBand(
                isVisible: true,
                start: 8.5,
                end: 25,
                color: const Color.fromRGBO(255, 178, 102, 1),
                opacity: 0.2),
          ]),
      series: _getDefaultDateTimeSeries(),
      trackballBehavior: _trackballBehavior,
    );
  }

  List<ScatterSeries<BgReading, DateTime>> _getDefaultDateTimeSeries() {
    return <ScatterSeries<BgReading, DateTime>>[
      ScatterSeries<BgReading, DateTime>(
        opacity: 1,
        markerSettings: const MarkerSettings(
          height: 8,
          width: 8,
        ),
        dataSource: datasource,
        pointColorMapper: (data, index) => selectColor(data.mmol),
        xValueMapper: (BgReading data, _) => data.time,
        yValueMapper: (BgReading data, _) => data.mmol,
        color: const Color.fromARGB(255, 107, 107, 107),
      )
    ];
  }

  StatefulWidget _buildCircularIndicator(BgReadingEntity? reading) {
    if (reading != null) {
      return StreamBuilder<DocumentSnapshot<DailyStatsEntity>>(
          stream: _pointsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('Something went wrong');
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return SizedBox(
                  width: 50,
                  height: 50,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Colors.blueAccent[700],
                    ),
                  ));
            }
            if (snapshot.data?.data() != null) {
              var dailyStats = snapshot.data!.data();
              if ((dailyGoal.isEven &&
                      (dailyStats!.points! / dailyGoal == 0.5)) ||
                  (dailyGoal.isOdd &&
                      (dailyStats!.points! / (dailyGoal + 1) == 0.5))) {
                NotificationService.showNotification(
                    title: "DIA App",
                    body:
                        "Dobrá práce! Právě jste splnili polovinu svého denního cíle.",
                    fln: flutterLocalNotificationsPlugin);
              }
              if ((dailyStats!.points! / dailyGoal) == 1) {
                NotificationService.showNotification(
                    title: "DIA App",
                    body: "Bravo, splnili jste dnešní denní cíl!",
                    fln: flutterLocalNotificationsPlugin);
              }
              return Padding(
                padding: const EdgeInsets.all(0),
                child: CircularPercentIndicator(
                  radius: circularSize,
                  lineWidth: circularSize / 10 * 2,
                  backgroundColor: Colors.white70,
                  percent: (dailyStats.points! / dailyGoal) > 1
                      ? 1
                      : dailyStats.points! / dailyGoal,
                  progressColor: const ui.Color.fromARGB(255, 5, 160, 243),
                  center: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        reading.mmol!.toString() + reading.trend!,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: streakRowSize + 5),
                      ),
                      Text(getTime(reading.time!),
                          style: const TextStyle(
                              fontWeight: FontWeight.w400, fontSize: 15))
                    ],
                  ),
                  header: Padding(
                    padding: EdgeInsets.only(
                        bottom: circularSize == 100 ? 25 : 5, top: 0),
                    child: const Text(
                      "Denní cíl",
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
                    ),
                  ),
                  circularStrokeCap: CircularStrokeCap.round,
                ),
              );
            } else {
              return Container(
                  padding: const EdgeInsets.only(top: 20),
                  child: Column(
                    children: const [
                      Text(
                        "Žádná data",
                        style: TextStyle(
                            fontSize: 35, fontWeight: FontWeight.w600),
                      ),
                      Icon(
                        Icons.error,
                        color: Colors.red,
                        size: 40,
                      )
                    ],
                  ));
            }
          });
    } else {
      return CircularPercentIndicator(
        radius: circularSize,
        lineWidth: 8,
        backgroundColor: Colors.white70,
        percent: 0,
        progressColor: const ui.Color.fromARGB(255, 5, 160, 243),
        center: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Žádná data",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Text(DateTime.now().toString().split(".")[0],
                style:
                    const TextStyle(fontWeight: FontWeight.w400, fontSize: 10))
          ],
        ),
        header: const Padding(
          padding: EdgeInsets.only(bottom: 10, top: 10),
          child: Text(
            "Denní cíl",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
          ),
        ),
        circularStrokeCap: CircularStrokeCap.round,
      );
    }
  }

  Row dailyGoalStreak() {
    int today = DateTime.now().weekday;
    if (dailyStats.isNotEmpty) {
      try {
        List<Column> lastDays = [
          Column(
            children: [
              Container(
                height: streakRowSize + 10,
                width: streakRowSize + 10,
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue, width: 3),
                    borderRadius: const BorderRadius.all(Radius.circular(45))),
                child: Center(
                  child: Text(
                    weekDays[today % 7]!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
          Column(
            children: [
              Text(
                weekDays[(today + 1) % 7]!,
              ),
              Container(
                height: streakRowSize,
                width: streakRowSize,
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue, width: 3),
                    borderRadius: const BorderRadius.all(Radius.circular(30))),
                child: Icon(
                  Icons.cancel_sharp,
                  color: Colors.grey,
                  size: streakRowSize - 8,
                ),
              ),
            ],
          ),
          Column(
            children: [
              Text(
                weekDays[(today + 2) % 7]!,
              ),
              Container(
                height: streakRowSize,
                width: streakRowSize,
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue, width: 3),
                    borderRadius: const BorderRadius.all(Radius.circular(30))),
                child: Icon(
                  Icons.cancel_sharp,
                  color: Colors.grey,
                  size: streakRowSize - 8,
                ),
              ),
            ],
          ),
          Column(
            children: [
              Text(
                weekDays[(today + 3) % 7]!,
              ),
              Container(
                height: streakRowSize,
                width: streakRowSize,
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue, width: 3),
                    borderRadius: const BorderRadius.all(Radius.circular(30))),
                child: Icon(
                  Icons.cancel_sharp,
                  color: Colors.grey,
                  size: streakRowSize - 8,
                ),
              ),
            ],
          ),
        ];
        List<Widget> days = dailyStats.map((e) {
          int index = 3 - dailyStats.indexOf(e);
          int statsDay = e.lastReading!.weekday % 7;
          if (dailyStats.length < 3 && e.points! >= dailyGoal) {
            return Column(
              children: [
                Text(
                  weekDays[statsDay]!,
                ),
                Container(
                  height: streakRowSize,
                  width: streakRowSize,
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue, width: 3),
                      borderRadius:
                          const BorderRadius.all(Radius.circular(35))),
                  child: Icon(Icons.check_circle_sharp,
                      color: Colors.green, size: streakRowSize - 8),
                ),
              ],
            );
          }
          if (e.points! >= dailyGoal && statsDay == ((today - index) % 7)) {
            return Column(
              children: [
                Text(
                  weekDays[statsDay]!,
                ),
                Container(
                  height: streakRowSize,
                  width: streakRowSize,
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue, width: 3),
                      borderRadius:
                          const BorderRadius.all(Radius.circular(35))),
                  child: Icon(Icons.check_circle_sharp,
                      color: Colors.green, size: streakRowSize - 8),
                ),
              ],
            );
          } else {
            return Column(
              children: [
                Text(
                  weekDays[statsDay]!,
                ),
                Container(
                  height: streakRowSize,
                  width: streakRowSize,
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue, width: 3),
                      borderRadius:
                          const BorderRadius.all(Radius.circular(35))),
                  child: Icon(Icons.cancel,
                      color: Colors.red, size: streakRowSize - 8),
                ),
              ],
            );
          }
        }).toList();

        days.addAll(lastDays);

        return (Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: days));
      } catch (e) {
        return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const []);
      }
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: streakRowSize,
            width: streakRowSize,
            decoration: BoxDecoration(
                border: Border.all(color: Colors.blue, width: 3),
                borderRadius: const BorderRadius.all(Radius.circular(30))),
          ),
          Container(
            height: streakRowSize,
            width: streakRowSize,
            decoration: BoxDecoration(
                border: Border.all(color: Colors.blue, width: 3),
                borderRadius: const BorderRadius.all(Radius.circular(30))),
          ),
          Container(
            height: streakRowSize,
            width: streakRowSize,
            decoration: BoxDecoration(
                border: Border.all(color: Colors.blue, width: 3),
                borderRadius: const BorderRadius.all(Radius.circular(30))),
          ),
          Container(
            height: streakRowSize + 10,
            width: streakRowSize + 10,
            decoration: BoxDecoration(
                border: Border.all(color: Colors.blue, width: 3),
                borderRadius: const BorderRadius.all(Radius.circular(45))),
            child: Center(
              child: Text(
                weekDays[today % 7]!,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 18),
              ),
            ),
          ),
          Container(
            height: streakRowSize,
            width: streakRowSize,
            decoration: BoxDecoration(
                border: Border.all(color: Colors.blue, width: 3),
                borderRadius: const BorderRadius.all(Radius.circular(30))),
          ),
          Container(
            height: streakRowSize,
            width: streakRowSize,
            decoration: BoxDecoration(
                border: Border.all(color: Colors.blue, width: 3),
                borderRadius: const BorderRadius.all(Radius.circular(30))),
          ),
          Container(
            height: streakRowSize,
            width: streakRowSize,
            decoration: BoxDecoration(
                border: Border.all(color: Colors.blue, width: 3),
                borderRadius: const BorderRadius.all(Radius.circular(30))),
          ),
        ],
      );
    }
  }

  Color selectColor(double bg) {
    if (bg == 0.0) {
      return Colors.blue.shade100;
    }
    if (bg < 4.0) {
      return Colors.redAccent[700]!;
    } else if (bg > 4.0 && bg < 8.5) {
      return Colors.green;
    } else {
      return Colors.deepOrange;
    }
  }

  List<Widget> get _toggleButtons {
    return const <Widget>[
      Text(
        "6H",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      Text(
        "12H",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      Text(
        "24H",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.height > 1000) {
      setState(() {
        streakRowSize = 40;
        circularSize = 100;
        mainHeight = 0.85;
      });
    } else if (MediaQuery.of(context).size.height > 700) {
      setState(() {
        streakRowSize = 30;
        circularSize = 80;
        mainHeight = 0.8;
      });
    }

    return RefreshIndicator(
      onRefresh: setUp,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
            height: MediaQuery.of(context).size.height * mainHeight,
            child: StreamBuilder<QuerySnapshot<BgReadingEntity>>(
                stream: _bgReadingStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Container(
                      padding: const EdgeInsets.only(bottom: 50),
                      decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(50),
                            bottomRight: Radius.circular(50),
                          )),
                      width: MediaQuery.of(context).size.width,
                      height: 200,
                      child: const Center(
                        child: Text('Něco se pokazilo',
                            style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w600,
                                color: Colors.red)),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      padding: const EdgeInsets.only(bottom: 50),
                      decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(50),
                            bottomRight: Radius.circular(50),
                          )),
                      width: MediaQuery.of(context).size.width,
                      height: 200,
                      child: Center(
                          child: CircularProgressIndicator(
                        color: Colors.blueAccent[700],
                      )),
                    );
                  }
                  if (snapshot.hasData && snapshot.data!.size != 0) {
                    var reading = snapshot.data?.docs.last.data();
                    if (reading != null) {
                      if (datasource.isNotEmpty) {
                        if (datasource.first.time != reading.time &&
                            !reading.time!
                                .difference(datasource.first.time)
                                .isNegative) {
                          datasource.removeLast();
                          datasource.insert(0, reading.toBgReading());
                        }
                      }
                      return (Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                              flex: 6,
                              child: Container(
                                  height: (circularSize + 10) * 2.5,
                                  padding: const EdgeInsets.only(bottom: 15),
                                  decoration: BoxDecoration(
                                      color: selectColor(reading.mmol!),
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(50),
                                        bottomRight: Radius.circular(50),
                                      )),
                                  width: MediaQuery.of(context).size.width,
                                  child: _buildCircularIndicator(reading))),
                          Flexible(
                              flex: 2,
                              child: SizedBox(
                                height: 75,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 20),
                                  child: dailyGoalStreak(),
                                ),
                              )),
                          Flexible(
                            flex: 1,
                            child: ToggleButtons(
                              direction: Axis.horizontal,
                              onPressed: (int index) {
                                setState(() {
                                  // The button that is tapped is set to true, and the others to false.
                                  for (int i = 0; i < intervals.length; i++) {
                                    intervals[i] = i == index;
                                  }
                                  switch (index) {
                                    case 0:
                                      selectedInterval = 6;
                                      break;
                                    case 1:
                                      selectedInterval = 12;
                                      break;
                                    case 2:
                                      selectedInterval = 24;
                                      break;
                                    default:
                                      selectedInterval = 6;
                                  }
                                });
                                apiController
                                    .getDataSource(selectedInterval)
                                    .then((value) {
                                  setState(() {
                                    datasource = value!;
                                  });
                                });
                              },
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(8)),
                              selectedBorderColor: Colors.blue[700],
                              selectedColor: Colors.white,
                              fillColor: Colors.blue[200],
                              color: Colors.blue[400],
                              constraints: BoxConstraints(
                                minHeight: streakRowSize + 10,
                                minWidth: 80.0,
                              ),
                              isSelected: intervals,
                              children: _toggleButtons,
                            ),
                          ),
                          Flexible(
                            flex: 8,
                            fit: FlexFit.loose,
                            child: _buildDefaultDateTimeAxisChart(),
                          ),
                        ],
                      ));
                    }
                  }
                  return Container(
                      padding: const EdgeInsets.only(bottom: 50),
                      decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(50),
                            bottomRight: Radius.circular(50),
                          )),
                      width: MediaQuery.of(context).size.width,
                      height: 200,
                      child: Column(
                        children: const [
                          Icon(
                            Icons.error,
                            size: 100,
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.0,
                            ),
                            child: Text(
                              "Pro zobrazení dat je nutné přihlásit se ke své DEXCOM Share službě v nastavení.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w500),
                            ),
                          )
                        ],
                      ));
                })),
      ),
    );
  }
}
