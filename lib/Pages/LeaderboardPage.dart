// ignore_for_file: use_build_context_synchronously, avoid_function_literals_in_foreach_calls

import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:js_flutter/repository/UserRepository.dart';
import 'package:js_flutter/entity/UserEntity.dart';
import 'package:js_flutter/utils/PointsUtils.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({Key? key}) : super(key: key);

  @override
  _LeaderboardPageState createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  List<UserEntity> users = [];
  List<UserEntity> friends = [];
  final _formKey = GlobalKey<FormState>();
  UserRepository userRepo = UserRepository();
  final nameController = TextEditingController();
  Timer? timer;
  bool userRemoval = false;
  User? currentUser = FirebaseAuth.instance.currentUser;
  List<Tab> tabs = <Tab>[
    const Tab(
      text: "Přátelé",
      icon: Icon(Icons.groups),
      height: 60,
    ),
    const Tab(
      text: "Veřejné",
      icon: Icon(Icons.public),
      height: 60,
    ),
  ];

  @override
  void initState() {
    super.initState();

    setUp();
  }

  @override
  void dispose() {
    users.clear();
    friends.clear();
    super.dispose();
  }

  void setUp() async {
    userRepo.retrieveAll().then((value) => setState(
          () {
            users = value;
          },
        ));
    userRepo.retrieveFriends().then((value) => setState(
          () {
            friends = value;
          },
        ));
  }

  void sortUsers() {
    users.sort(((a, b) => b.points!.compareTo(a.points!)));
  }

  void sortFriends() {
    friends.sort(((a, b) => b.points!.compareTo(a.points!)));
  }

  bool validateFriend(String name) {
    bool result = false;

    for (var friend in friends) {
      if (friend.name == name) {
        result = true;
      }
    }

    return result;
  }

  Widget buildFriendInput(BuildContext context) {
    return AlertDialog(
      content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                "Přidejte nového přítele",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  hintText: 'Nickname přítele',
                ),
                autocorrect: false,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Zadejte nickname!';
                  }
                  return null;
                },
              ),
              ElevatedButton(
                  onPressed: (() async {
                    var name = nameController.text.trim();
                    if (_formKey.currentState!.validate()) {
                      bool valid = await userRepo.checkUser(name);
                      if (valid) {
                        FirebaseAnalytics.instance
                            .logEvent(name: "addFriend", parameters: null);
                        userRepo.addFriend(name);
                        Navigator.pop(context);
                        setUp();
                        nameController.clear();
                      } else {
                        Navigator.pop(context);
                        nameController.clear();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Uživatel se zadaným nickname neexistuje!',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }),
                  child: const Text("Přidat"))
            ],
          )),
    );
  }

  List<ListTile> buildTabView(Tab tab) {
    List<ListTile> tiles = [];
    String dpName = "";
    if (currentUser != null) {
      dpName = currentUser!.displayName!;
    }
    if (tab.text == "Přátelé") {
      tiles.add(ListTile(
        title: Row(
          children: [
            Expanded(
              child: TextButton.icon(
                  onPressed: (() {
                    showDialog(context: context, builder: buildFriendInput);
                  }),
                  icon: const Icon(Icons.person_add),
                  label: const Text(
                    "Přidat přítele",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  )),
            ),
            Expanded(
              child: TextButton.icon(
                  onPressed: (() {
                    setState(() {
                      userRemoval = !userRemoval;
                    });
                  }),
                  icon: const Icon(Icons.person_off, color: Colors.red),
                  label: const Text(
                    "Odebrat přitele",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.red),
                  )),
            ),
          ],
        ),
      ));
      if (friends.isNotEmpty) {
        sortFriends();
        friends.forEach((friend) {
          if (friend.name != null) {
            tiles.add(ListTile(
              tileColor: Colors.blue[50],
              iconColor: Colors.blue,
              leading: userRemoval
                  ? IconButton(
                      tooltip: "Odeber přítele",
                      color: Colors.red,
                      onPressed: () {
                        userRepo.removeFriend(friend.name!);
                        FirebaseAnalytics.instance
                            .logEvent(name: "removeFriend", parameters: null);
                        setState(() {
                          userRemoval = false;
                        });
                        setUp();
                      },
                      icon: const Icon(Icons.delete_forever))
                  : const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.person),
                    ),
              enabled: true,
              title: Text(friend.name!,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: Text("Celkové body: " + friend.points.toString()),
              isThreeLine: true,
              trailing: CircularPercentIndicator(
                radius: 25,
                circularStrokeCap: CircularStrokeCap.round,
                lineWidth: 8,
                percent: getLevelProgress(friend.level!, friend.points!),
                restartAnimation: true,
                progressColor: Colors.green,
                center: Text(friend.level.toString(),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 20)),
              ),
            ));
          }
        });
      }
    } else if (tab.text == "Veřejné") {
      if (users.isNotEmpty) {
        sortUsers();
        int placement = 1;
        users.forEach((user) {
          if (user.name != null) {
            tiles.add(ListTile(
              tileColor:
                  dpName == user.name ? Colors.amber.shade300 : Colors.blue[50],
              iconColor: Colors.blue,
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  "$placement.",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 25),
                ),
              ),
              title: Text(user.name!,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: Text("Celkové body: ${user.points}"),
              isThreeLine: true,
              minVerticalPadding: 22,
              trailing: CircularPercentIndicator(
                radius: 25,
                circularStrokeCap: CircularStrokeCap.round,
                lineWidth: 8,
                percent: getLevelProgress(user.level!, user.points!),
                restartAnimation: true,
                progressColor: Colors.green,
                center: Text(user.level.toString(),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 20)),
              ),
            ));
          }
          placement++;
        });
      }
    }
    return tiles;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabs.length,
      child: Builder(builder: (BuildContext context) {
        final TabController tabController = DefaultTabController.of(context)!;
        tabController.addListener(() {
          if (!tabController.indexIsChanging) {
            // Your code goes here.
            // To get index of current tab use tabController.index
          }
        });
        return Column(children: [
          TabBar(
            labelPadding: EdgeInsets.zero,
            indicatorPadding: EdgeInsets.zero,
            indicatorWeight: 4,
            tabs: tabs,
            labelColor: Colors.blue,
            onTap: (value) {
              setUp();
            },
          ),
          Expanded(
            child: TabBarView(
              children: tabs.map((Tab tab) {
                return ListView(
                    padding: const EdgeInsets.only(top: 0),
                    children: buildTabView(tab));
              }).toList(),
            ),
          ),
        ]);
      }),
    );
  }
}
