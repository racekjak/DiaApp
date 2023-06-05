import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DBConnector {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final user = FirebaseAuth.instance.currentUser;

  FirebaseFirestore init() {
    //db.useFirestoreEmulator('10.0.2.2', 8080);
    return db;
  }
}
