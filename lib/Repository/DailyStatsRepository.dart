// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:js_flutter/repository/BgReadingRepository.dart';
import 'package:js_flutter/repository/PointsRepository.dart';
import 'package:js_flutter/repository/UserRepository.dart';
import 'package:js_flutter/dataTypes/bgReading.dart';
import 'package:js_flutter/entity/BgReadingEntity.dart';
import 'package:js_flutter/entity/DailyStatsEntity.dart';
import 'package:js_flutter/utils/BgUtils.dart';
import 'package:js_flutter/utils/DateUtils.dart';
import 'package:js_flutter/services/apiController.dart';
import 'package:js_flutter/repository/DBConnector.dart';

class DailyStatsRepository {
  final FirebaseFirestore database = DBConnector().init();
  final user = FirebaseAuth.instance.currentUser;
  PointsRepository pointsRepository = PointsRepository();
  UserRepository userRepo = UserRepository();

  Future<DailyStatsEntity?> getMyDailyStats(DateTime date) async {
    try {
      DocumentReference<DailyStatsEntity> dailyStats = database
          .collection("users/${user!.displayName!}/dailyStats")
          .doc(getDate(date))
          .withConverter(
            fromFirestore: DailyStatsEntity.fromFirestore,
            toFirestore: (DailyStatsEntity entity, options) =>
                entity.toFirestore(),
          );
      DocumentSnapshot<DailyStatsEntity> today = await dailyStats.get();

      return today.data()!;
    } catch (e) {
      print(e);
      return null;
    }
  }

  Future<List<DailyStatsEntity>?> getMyDailyStatsFor(int days) async {
    try {
      QuerySnapshot<DailyStatsEntity> dailyStats = await database
          .collection("users/${user!.displayName!}/dailyStats")
          .withConverter(
            fromFirestore: DailyStatsEntity.fromFirestore,
            toFirestore: (DailyStatsEntity entity, options) =>
                entity.toFirestore(),
          )
          .orderBy("lastReading", descending: true)
          .limit(days)
          .get();

      List<DailyStatsEntity> dailyStatsDocs =
          dailyStats.docs.map((doc) => doc.data()).toList();
      return dailyStatsDocs;
    } catch (e) {
      print(e);
      return null;
    }
  }

  Future<bool> setUpDailyStats(DateTime date) async {
    bool result = false;
    try {
      DocumentReference<DailyStatsEntity> dailyStats = database
          .collection("users/${user!.displayName!}/dailyStats")
          .doc(getDate(date))
          .withConverter(
            fromFirestore: DailyStatsEntity.fromFirestore,
            toFirestore: (DailyStatsEntity entity, options) =>
                entity.toFirestore(),
          );
      await dailyStats
          .set(
              DailyStatsEntity(points: 0, lows: 0, highs: 0, lastReading: date))
          .then((value) {
        result = true;
        return result;
      }).catchError((err) {
        print(err);
        return result;
      });
    } catch (e) {
      print(e);
      return result;
    }
    return result;
  }

  Future<void> updateDailyStats(BgReadingEntity reading) async {
    try {
      var exist = await getMyDailyStats(reading.time!);
      if (exist != null) {
        DocumentReference<DailyStatsEntity> dailyStats = database
            .collection("users/${user!.displayName!}/dailyStats")
            .doc(getDate(reading.time!))
            .withConverter(
              fromFirestore: DailyStatsEntity.fromFirestore,
              toFirestore: (DailyStatsEntity entity, options) =>
                  entity.toFirestore(),
            );
        if (inRange(reading.mmol!)) {
          dailyStats.update({'points': FieldValue.increment(1)});
        } else {
          if (reading.mmol! >= 8.5) {
            dailyStats.update({'highs': FieldValue.increment(1)});
          } else {
            dailyStats.update({'lows': FieldValue.increment(1)});
          }
        }
      } else {
        await setUpDailyStats(reading.time!).then((value) async {
          if (value) {
            DocumentReference<DailyStatsEntity> dailyStats = database
                .collection("users/${user!.displayName!}/dailyStats")
                .doc(getDate(reading.time!))
                .withConverter(
                  fromFirestore: DailyStatsEntity.fromFirestore,
                  toFirestore: (DailyStatsEntity entity, options) =>
                      entity.toFirestore(),
                );
            if (inRange(reading.mmol!)) {
              dailyStats.update({'points': FieldValue.increment(1)});
            } else {
              if (reading.mmol! >= 8.5) {
                dailyStats.update({'highs': FieldValue.increment(1)});
              } else {
                dailyStats.update({'lows': FieldValue.increment(1)});
              }
            }
          }
        });
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> syncReadings(String id, String pwd) async {
    BgReadingRepository bgRepo = BgReadingRepository();
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DateTime now = DateTime.now();
        DateTime todayStart = DateTime(now.year, now.month, now.day);
        BgReadingEntity? firstReading = await bgRepo.getFirstReading();
        BgReadingEntity? lastReading = await bgRepo.getLastReading();
        BgReadingEntity? secondLastReading =
            await bgRepo.getSecondLastReading();
        if (firstReading == null) {
          List<BgReading>? list = await ApiController()
              .getDataSource(now.difference(todayStart).inHours + 1);
          if (list != null && list.isNotEmpty) {
            for (var reading in list) {
              await bgRepo.create(BgReadingEntity(
                  mmol: reading.mmol,
                  time: reading.time,
                  trend: reading.trend));
            }
          }
          return;
        }

        if (firstReading.time!.difference(todayStart).inMinutes > 10) {
          List<BgReading>? list = await ApiController().getDataSource(
              firstReading.time!.difference(todayStart).inHours + 1);
          if (list != null && list.isNotEmpty) {
            for (var reading in list) {
              await bgRepo.create(BgReadingEntity(
                  mmol: reading.mmol,
                  time: reading.time,
                  trend: reading.trend));
            }
          }
          return;
        }

        if (lastReading == null || secondLastReading == null) {
          return;
        }

        if (lastReading.time!.difference(secondLastReading.time!).inMinutes >
            10) {
          List<BgReading>? list = await ApiController().getDataSource(
              lastReading.time!.difference(secondLastReading.time!).inHours +
                  1);
          if (list != null && list.isNotEmpty) {
            for (var reading in list) {
              await bgRepo.create(BgReadingEntity(
                  mmol: reading.mmol,
                  time: reading.time,
                  trend: reading.trend));
            }
          }
          return;
        }
      }
    } catch (e) {
      print(e);
    }
  }
}
