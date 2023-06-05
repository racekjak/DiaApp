import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:js_flutter/repository/DailyStatsRepository.dart';
import 'package:js_flutter/repository/PointsRepository.dart';
import 'package:js_flutter/repository/UserRepository.dart';
import 'package:js_flutter/entity/DailyStatsEntity.dart';
import 'package:js_flutter/utils/PointsUtils.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({Key? key}) : super(key: key);

  @override
  _StatsPageState createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  User? currentUser = FirebaseAuth.instance.currentUser;
  UserRepository userRepo = UserRepository();
  PointsRepository pointsRepository = PointsRepository();
  DailyStatsRepository dailySatsRepo = DailyStatsRepository();
  int points = 0;
  int level = 1;
  List<bool> timeFrames = [true, false, false];
  int selectedTimeFrame = 1;
  int touchedIndex = -1;
  int? showingTooltip;
  int floatingPoint = 1;

  @override
  void initState() {
    super.initState();
    userRepo.retrieve(currentUser!.displayName!).then((value) => setState(
          () {
            points = value!.points!;
            level = value.level!;
          },
        ));
  }

  Widget _buildPieChart(List<PieChartSectionData> data) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(0),
        child: (AspectRatio(
          aspectRatio: 1,
          child: PieChart(
            PieChartData(
                borderData: FlBorderData(
                  show: false,
                ),
                sectionsSpace: 1,
                centerSpaceRadius: 15,
                sections: data),
          ),
        )),
      ),
    );
  }

  List<PieChartSectionData> _createInRangeData(
      int highs, int lows, int points) {
    List<PieChartSectionData> data = [];
    data.add(PieChartSectionData(
      color: Colors.green,
      value: points.toDouble(),
      title: 'V rozmezí',
      radius: 50,
      titleStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Color(0xffffffff),
      ),
    ));
    data.add(PieChartSectionData(
      color: Colors.redAccent[700]!,
      value: (lows + highs).toDouble(),
      title: 'Mimo',
      radius: 50,
      titleStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Color(0xffffffff),
      ),
    ));

    return data;
  }

  Widget _buildBarChart(int highs, int lows) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(top: 5, left: 5, right: 5),
        child: AspectRatio(
          aspectRatio: 2,
          child: BarChart(
            BarChartData(
                barGroups: [
                  generateGroupData(1, highs),
                  generateGroupData(2, lows),
                ],
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                    show: true,
                    topTitles: AxisTitles(),
                    leftTitles: AxisTitles(),
                    rightTitles: AxisTitles(),
                    bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const style = TextStyle(
                          fontSize: 14,
                        );
                        String text;
                        switch (value.toInt()) {
                          case 1:
                            text = "Vysoké";
                            break;
                          case 2:
                            text = "Nízké";
                            break;
                          default:
                            text = "";
                        }
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(text, style: style),
                        );
                      },
                    )))),
          ),
        ),
      ),
    );
  }

  BarChartGroupData generateGroupData(int x, int y) {
    return BarChartGroupData(
      x: x,
      showingTooltipIndicators: showingTooltip == x ? [0] : [],
      barRods: [
        BarChartRodData(
            toY: y.toDouble(),
            color: x == 1 ? Colors.deepOrange : Colors.redAccent.shade700,
            width: 20),
      ],
    );
  }

  Widget _buildTopTile() {
    return (Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(0.5),
                spreadRadius: 5,
                blurRadius: 7,
                offset: const Offset(0, 3))
          ]),
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          CircleAvatar(
            child: Text(
              level.toStringAsFixed(0),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            backgroundColor: Colors.orangeAccent,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(currentUser!.displayName!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.start),
                Stack(
                  children: [
                    SizedBox(
                      height: 18,
                      width: 200,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          backgroundColor: Colors.orangeAccent,
                          color: Colors.blue,
                          value: getLevelProgress(level, points),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              points.toStringAsFixed(0) +
                  "/" +
                  ((level + ((level / 5) * level)) * 75)
                      .floor()
                      .toStringAsFixed(0),
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          )
        ],
      ),
    ));
  }

  Widget _buildToggleButtons() {
    return (ToggleButtons(
      direction: Axis.horizontal,
      onPressed: (int index) {
        setState(() {
          for (int i = 0; i < timeFrames.length; i++) {
            timeFrames[i] = i == index;
          }
          switch (index) {
            case 0:
              selectedTimeFrame = 1;
              break;
            case 1:
              selectedTimeFrame = 7;
              break;
            case 2:
              selectedTimeFrame = 14;
              break;
            default:
              selectedTimeFrame = 1;
          }
        });
      },
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      selectedBorderColor: Colors.blue[700],
      selectedColor: Colors.white,
      fillColor: Colors.blue[200],
      color: Colors.blue[400],
      constraints: const BoxConstraints(
        minHeight: 40.0,
        minWidth: 80.0,
      ),
      isSelected: timeFrames,
      children: const <Widget>[
        Text(
          "Dnes",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        Text(
          "7 dní",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        Text(
          "14 dní",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ],
    ));
  }

  Widget _statsBuilder() {
    return (FutureBuilder<List<DailyStatsEntity>?>(
      future: dailySatsRepo.getMyDailyStatsFor(selectedTimeFrame),
      builder: (context, snapshot) {
        int highs = 0;
        int lows = 0;
        int pointsStats = 0;
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(8),
            child: const Center(
              child: Text('Něco se pokazilo',
                  style: TextStyle(fontSize: 35, fontWeight: FontWeight.w600)),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(10),
            child: Center(
                child: CircularProgressIndicator(
              color: Colors.blueAccent[700],
            )),
          );
        }

        if (snapshot.data != null && snapshot.data!.isNotEmpty) {
          for (var stat in snapshot.data!) {
            highs += stat.highs!;
            lows += stat.lows!;
            pointsStats += stat.points!;
          }

          return Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(
                      padding:
                          const EdgeInsets.only(bottom: 10, left: 5, right: 5),
                      height: 150,
                      width: (MediaQuery.of(context).size.width / 2) - 20,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.grey.withOpacity(0.5),
                                spreadRadius: 5,
                                blurRadius: 7,
                                offset: const Offset(0, 3))
                          ]),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 45),
                            child: Text(
                                "${((pointsStats / (pointsStats + lows + highs)) * 100).toStringAsFixed((highs == 0 && lows == 0) ? 0 : 1)}%",
                                style: TextStyle(
                                    fontSize: 53,
                                    fontWeight: FontWeight.w500,
                                    fontStyle: FontStyle.italic,
                                    color: pickColor(((pointsStats /
                                            (pointsStats + lows + highs)) *
                                        100)))),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 0),
                            child: Text("Time in Range",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                )),
                          ),
                        ],
                      )),
                  Container(
                      padding:
                          const EdgeInsets.only(bottom: 10, left: 5, right: 5),
                      height: 150,
                      width: (MediaQuery.of(context).size.width / 2) - 20,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.grey.withOpacity(0.5),
                                spreadRadius: 5,
                                blurRadius: 7,
                                offset: const Offset(0, 3))
                          ]),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 45),
                            child: Text(pointsStats.toString(),
                                style: const TextStyle(
                                    fontSize: 53,
                                    fontWeight: FontWeight.w500,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.green)),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 0),
                            child: Text("Získané body",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                )),
                          ),
                        ],
                      )),
                ],
              ),
              const SizedBox(
                height: 15,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(
                      padding:
                          const EdgeInsets.only(bottom: 10, left: 5, right: 5),
                      height: 200,
                      width: (MediaQuery.of(context).size.width / 2) - 20,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.grey.withOpacity(0.5),
                                spreadRadius: 5,
                                blurRadius: 7,
                                offset: const Offset(0, 3))
                          ]),
                      child: Column(
                        //mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          const Padding(
                            padding:
                                EdgeInsets.only(top: 5, left: 8, bottom: 0),
                            child: Text(
                              "Poměr vysokých a nízkých glykémií",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _buildBarChart(highs, lows),
                        ],
                      )),
                  Container(
                      padding:
                          const EdgeInsets.only(bottom: 10, left: 5, right: 5),
                      height: 200,
                      width: (MediaQuery.of(context).size.width / 2) - 20,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.grey.withOpacity(0.5),
                                spreadRadius: 5,
                                blurRadius: 7,
                                offset: const Offset(0, 3))
                          ]),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                                top: 5, left: 8, bottom: 0),
                            child: Text(
                              "Průběžný stav hodnot za $selectedTimeFrame dní",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _buildPieChart(
                              _createInRangeData(highs, lows, pointsStats)),
                        ],
                      ))
                ],
              ),
            ],
          );
        }

        return Container();
      },
    ));
  }

  Color pickColor(double tir) {
    if (tir > 75) {
      return Colors.green;
    }
    if (tir >= 70) {
      return Colors.yellow.shade700;
    }
    if (tir > 50) {
      return Colors.orange.shade700;
    }
    return Colors.red.shade700;
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.height > 700) {
      return Padding(
        padding: const EdgeInsets.only(top: 5, left: 5, right: 5),
        child: SizedBox(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              _buildTopTile(),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 15),
                child: Text("Uživatelské statistiky",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 25)),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _buildToggleButtons(),
              ),
              _statsBuilder(),
            ],
          ),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.only(top: 5, left: 5, right: 5),
        child: SingleChildScrollView(
          child: SizedBox(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                _buildTopTile(),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 15),
                  child: Text("Uživatelské statistiky",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 25)),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _buildToggleButtons(),
                ),
                _statsBuilder(),
              ],
            ),
          ),
        ),
      );
    }
  }
}
