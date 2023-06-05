// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:js_flutter/entity/BgReadingEntity.dart';
import 'package:js_flutter/entity/UserEntity.dart';
import 'package:js_flutter/utils/BgUtils.dart';
import 'package:js_flutter/repository/DBConnector.dart';

class PointsRepository {
  final FirebaseFirestore database = DBConnector().init();

  Future<int> getMyPoints() async {
    User? user = FirebaseAuth.instance.currentUser;
    int myPoints = 0;
    if (user != null) {
      final userRef =
          database.collection("users").doc(user.displayName).withConverter(
                fromFirestore: UserEntity.fromFirestore,
                toFirestore: (UserEntity user, _) => user.toFirestore(),
              );

      final doc = await userRef.get();

      if (doc.data() != null && doc.data()?.points != null) {
        myPoints = doc.data()!.points!;
      }
    }
    return myPoints;
  }

  Future<void> updatePoints(BgReadingEntity reading) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null && inRange(reading.mmol!)) {
        final userRef = database.collection("users").doc(user.displayName);
        await database.runTransaction((transaction) async {
          final snapshot = await transaction.get(userRef);
          final newPoints = snapshot.get("points") + 1;
          var points = snapshot.get("points");
          var level = snapshot.get("level");
          var levelProgress =
              ((points + 1) / ((level + ((level / 5) * level)) * 75).floor());

          if (levelProgress == 1.0) {
            final newLevel = snapshot.get("level") + 1;
            transaction
                .update(userRef, {"points": newPoints, "level": newLevel});
          } else {
            transaction.update(userRef, {
              "points": newPoints,
            });
          }
        }).onError((error, stackTrace) {
          print(error);
        }).catchError((error) {
          print(error);
        });
      }
    } catch (e) {
      print("Transaction error: " + e.toString());
    }
  }
}
