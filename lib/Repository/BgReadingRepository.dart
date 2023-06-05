import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:js_flutter/pages/MainPage.dart';
import 'package:js_flutter/repository/DailyStatsRepository.dart';
import 'package:js_flutter/repository/PointsRepository.dart';
import 'package:js_flutter/repository/UserRepository.dart';
import 'package:js_flutter/entity/BgReadingEntity.dart';
import 'package:js_flutter/utils/DateUtils.dart';
import 'package:js_flutter/repository/DBConnector.dart';

class BgReadingRepository {
  final FirebaseFirestore database = DBConnector().init();
  final user = FirebaseAuth.instance.currentUser;
  PointsRepository pointsRepository = PointsRepository();
  UserRepository userRepo = UserRepository();
  DailyStatsRepository dailyRepo = DailyStatsRepository();
  HomePageController? myController;

  void getController(HomePageController controller) {
    myController = controller;
  }

  Future<BgReadingEntity> create(BgReadingEntity entity) async {
    var user = FirebaseAuth.instance.currentUser;
    Map<String, dynamic> latestReading = entity.toFirestore();
    var date = getDate(entity.time!);
    var time = getTime(entity.time!);
    double tmp = 0.5;
    try {
      if (await isNewReading(entity)) {
        database
            .collection('users/${user!.displayName!}/$date')
            .doc(time)
            .set(latestReading);

        await pointsRepository.updatePoints(entity);
        dailyRepo.updateDailyStats(entity);
      }
      return entity;
    } catch (e) {
      print(e);
      return entity;
    }
  }

  Future<bool> isNewReading(BgReadingEntity reading) async {
    var user = FirebaseAuth.instance.currentUser;
    bool result = false;
    if (user != null) {
      try {
        var readingRef = database
            .collection("users/${user.displayName}/${getDate(reading.time!)}")
            .doc(getTime(reading.time!));
        await readingRef.get().then((doc) {
          if (doc.exists) {
            return result;
          } else {
            result = true;
            return result;
          }
        });
      } catch (e) {
        return result;
      }
    }

    return result;
  }

  Future<BgReadingEntity?> getLastReading() async {
    var user = FirebaseAuth.instance.currentUser;
    BgReadingEntity? result;
    if (user != null) {
      try {
        CollectionReference dayCollection = database.collection(
            "users/${user.displayName!}/${getDate(DateTime.now())}");
        await dayCollection
            .orderBy("time", descending: true)
            .limit(1)
            .withConverter(
              fromFirestore: BgReadingEntity.fromFirestore,
              toFirestore: (BgReadingEntity entity, options) =>
                  entity.toFirestore(),
            )
            .get()
            .then((value) {
          if (value.docs.isEmpty) {
            result = null;
          } else {
            result = value.docs.single.data();
          }
        });
      } catch (e) {
        return result;
      }
    }

    return result;
  }

  Future<BgReadingEntity?> getSecondLastReading() async {
    var user = FirebaseAuth.instance.currentUser;
    BgReadingEntity? result;
    if (user != null) {
      try {
        CollectionReference dayCollection = database.collection(
            "users/${user.displayName!}/${getDate(DateTime.now())}");
        await dayCollection
            .orderBy("time", descending: true)
            .limit(2)
            .withConverter(
              fromFirestore: BgReadingEntity.fromFirestore,
              toFirestore: (BgReadingEntity entity, options) =>
                  entity.toFirestore(),
            )
            .get()
            .then((value) {
          if (value.docs.isEmpty) {
            result = null;
          } else {
            result = value.docs.last.data();
          }
        });
      } catch (e) {
        return result;
      }
    }

    return result;
  }

  Future<BgReadingEntity?> getFirstReading() async {
    var user = FirebaseAuth.instance.currentUser;
    BgReadingEntity? result;
    if (user != null) {
      try {
        CollectionReference dayCollection = database.collection(
            "users/${user.displayName!}/${getDate(DateTime.now())}");
        await dayCollection
            .orderBy("time", descending: false)
            .limit(1)
            .withConverter(
              fromFirestore: BgReadingEntity.fromFirestore,
              toFirestore: (BgReadingEntity entity, options) =>
                  entity.toFirestore(),
            )
            .get()
            .then((value) {
          if (value.docs.isEmpty) {
            result = null;
          } else {
            result = value.docs.single.data();
          }
        });
      } catch (e) {
        return result;
      }
    }

    return result;
  }
}
