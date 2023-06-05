import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:js_flutter/entity/BaseEntity.dart';

class UserEntity extends BaseEntity {
  String? name;
  int? level;
  int? points;
  List<String>? friends;

  UserEntity({this.name, this.level, this.points, this.friends});

  @override
  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      "name": name,
      "level": level,
      "points": points,
      "friends": friends
    };
  }

  factory UserEntity.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot,
      SnapshotOptions? options) {
    final data = snapshot.data();

    return UserEntity(
        name: data?['name'],
        level: data?['level'],
        points: data?['points'],
        friends: data?['friends'] is Iterable
            ? List.from(data?['friends'])
            : <String>[]);
  }
}
