// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:js_flutter/entity/UserEntity.dart';
import 'package:js_flutter/repository/DBConnector.dart';

class UserRepository {
  final FirebaseFirestore database = DBConnector().init();

  Future<UserEntity> create(UserEntity entity) async {
    database
        .collection("users")
        .doc(entity.name)
        .set(entity.toFirestore())
        .onError((e, _) => print("Error writing document: $e"));
    return entity;
  }

  Future<bool> delete(int id) async {
    database.collection("users").doc("Tester").delete().then(
          (value) => print("Document deleted"),
          onError: (e) => print("Error updating document $e"),
        );
    return true;
  }

  Future<void> update(UserEntity entity, int id) {
    throw UnimplementedError();
  }

  Future<UserEntity?> retrieve(String name) async {
    var currentUser = FirebaseAuth.instance.currentUser;
    UserEntity user = UserEntity();
    if (currentUser?.displayName != null) {
      DocumentReference document =
          database.collection("users").doc(currentUser?.displayName);
      await document
          .withConverter(
            fromFirestore: UserEntity.fromFirestore,
            toFirestore: (UserEntity user, _) => user.toFirestore(),
          )
          .get()
          .then((value) => user = value.data()!);
      return user;
    } else {
      return user;
    }
  }

  Future<List<UserEntity>> retrieveAll() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    List<UserEntity> users = [];
    final ref = database.collection("users").withConverter(
          fromFirestore: UserEntity.fromFirestore,
          toFirestore: (UserEntity user, _) => user.toFirestore(),
        );
    final documents = await ref.get();
    documents.docs.forEach((doc) {
      users.add(doc.data());
    });
    return users;
  }

  Future<bool> addFriend(String name) async {
    User? user = FirebaseAuth.instance.currentUser;
    bool success = false;
    if (user != null) {
      DocumentReference document =
          database.collection("users").doc(user.displayName);
      document.update({
        "friends": FieldValue.arrayUnion([name])
      }).catchError((err) {
        print('Error: $err');
        success = false;
      });
      success = true;
      return success;
    } else {
      return success;
    }
  }

  Future<bool> checkUser(String name) async {
    bool result = false;
    final userRef = database.collection("users").doc(name);

    await userRef.get().then((snapshot) {
      if (snapshot.exists) {
        result = true;
      } else {
        result = false;
      }
    });

    return result;
  }

  Future<List<UserEntity>> retrieveFriends() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    List<UserEntity> users = [];
    if (currentUser != null) {
      final userRef = database
          .collection("users")
          .doc(currentUser.displayName)
          .withConverter(
            fromFirestore: UserEntity.fromFirestore,
            toFirestore: (UserEntity user, _) => user.toFirestore(),
          );
      final user = await userRef.get();
      final friends = user.data()?.friends;
      if (friends != null) {
        for (var friend in friends) {
          await database
              .collection("users")
              .doc(friend)
              .withConverter(
                fromFirestore: UserEntity.fromFirestore,
                toFirestore: (UserEntity user, _) => user.toFirestore(),
              )
              .get()
              .then((value) {
            if (value.data() != null) {
              users.add(value.data()!);
            }
          });
        }
      }
    }
    return users;
  }

  Future<bool> removeFriend(String name) async {
    var user = FirebaseAuth.instance.currentUser;
    bool success = false;
    if (user?.displayName != null) {
      DocumentReference document =
          database.collection("users").doc(user?.displayName);
      document.update({
        "friends": FieldValue.arrayRemove([name])
      }).catchError((err) {
        print('Error: $err');
        success = false;
      });
      success = true;
      return success;
    } else {
      return success;
    }
  }
}
