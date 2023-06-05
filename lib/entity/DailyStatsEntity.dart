import 'package:cloud_firestore/cloud_firestore.dart';

import 'BaseEntity.dart';

class DailyStatsEntity extends BaseEntity {
  int? points;
  int? highs;
  int? lows;
  DateTime? lastReading;

  DailyStatsEntity({this.points, this.highs, this.lows, this.lastReading});

  factory DailyStatsEntity.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot,
      SnapshotOptions? options) {
    final data = snapshot.data();
    var timestamp = data?['lastReading'];
    return DailyStatsEntity(
        points: data?['points'],
        highs: data?['highs'],
        lows: data?['lows'],
        lastReading: DateTime.fromMillisecondsSinceEpoch(
            timestamp.millisecondsSinceEpoch));
  }

  @override
  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      "points": points,
      "highs": highs,
      "lows": lows,
      "lastReading": lastReading
    };
  }
}
