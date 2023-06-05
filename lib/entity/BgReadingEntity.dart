import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:js_flutter/dataTypes/bgReading.dart';
import 'package:js_flutter/entity/BaseEntity.dart';

class BgReadingEntity extends BaseEntity {
  String? trend;
  DateTime? time;
  double? mmol;

  BgReadingEntity({this.trend, this.time, this.mmol});

  factory BgReadingEntity.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot,
      SnapshotOptions? options) {
    final data = snapshot.data();
    var timestamp = data?['time'];
    return BgReadingEntity(
        trend: data?['trend'],
        time: DateTime.fromMillisecondsSinceEpoch(
            timestamp.millisecondsSinceEpoch),
        mmol: data?['mmol']);
  }

  @override
  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      "trend": trend,
      "time": time,
      "mmol": mmol,
    };
  }

  BgReading toBgReading() {
    return BgReading(mmol!, trend!, time!);
  }
}
