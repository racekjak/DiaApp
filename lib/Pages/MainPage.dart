import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/ui/with_foreground_task.dart';
import 'package:js_flutter/pages/HomePage.dart';
import 'package:js_flutter/pages/LeaderboardPage.dart';
import 'package:js_flutter/pages/SettingsPage.dart';
import 'package:js_flutter/pages/StatsPage.dart';
import 'package:js_flutter/services/aplicationstate.dart';
import 'package:js_flutter/pages/authentication.dart';
import 'package:provider/provider.dart';

class HomePageController {
  void Function()? cleanUp;
  void Function()? setUp;
  void Function()? addPoints;
  void Function()? setPrefs;
}

class MainPage extends StatefulWidget {
  const MainPage({
    Key? key,
    required this.title,
    required this.startCallback,
    required this.analytics,
    required this.observer,
  }) : super(key: key);
  final String title;
  final Function startCallback;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int currentIndex = 1;
  String? displayName = "";
  final HomePageController myController = HomePageController();
  Map<int, String> pageNames = {0: "statistiky", 1: "graf", 2: "žebříček"};

  @override
  void initState() {
    super.initState();
  }

  void onItemTap(int newIndex) {
    setState(() {
      currentIndex = newIndex;
      pageController.animateToPage(newIndex,
          duration: const Duration(milliseconds: 500), curve: Curves.ease);
    });
  }

  void pageChanged(int index) {
    setState(() {
      currentIndex = index;
    });
    widget.analytics.setCurrentScreen(
      screenName: pageNames[index],
      screenClassOverride: pageNames[index]!,
    );
  }

  List<BottomNavigationBarItem> buildBottomNavBarItems() {
    return const [
      BottomNavigationBarItem(
          label: "Statistiky", icon: Icon(Icons.analytics_outlined)),
      BottomNavigationBarItem(label: "Graf glykémie", icon: Icon(Icons.home)),
      BottomNavigationBarItem(label: "Žebříček", icon: Icon(Icons.leaderboard))
    ];
  }

  PageController pageController =
      PageController(initialPage: 1, keepPage: true);

  Widget buildPageView() {
    return PageView(
      controller: pageController,
      onPageChanged: pageChanged,
      children: [
        const StatsPage(),
        HomePage(
          controller: myController,
          startCallback: widget.startCallback,
        ),
        const LeaderboardPage()
      ],
    );
  }

  void setUserID() async {
    await widget.analytics
        .setUserProperty(name: 'user_name', value: displayName);
  }

  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            displayName = snapshot.data?.displayName;
            if (displayName != null && displayName != "") {
              setUserID();
            }
            return (Scaffold(
              extendBodyBehindAppBar: false,
              appBar: AppBar(
                title: Text(widget.title),
                actions: [
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: "settings",
                        child: TextButton.icon(
                          label: const Text("Nastavení"),
                          icon: const Icon(Icons.settings),
                          onPressed: () {
                            Navigator.pop(context, "settings");
                          },
                        ),
                      ),
                      PopupMenuItem(
                        value: "logout",
                        child: TextButton.icon(
                          label: const Text("Odhlásit se"),
                          icon: const Icon(Icons.logout),
                          onPressed: () {
                            Navigator.pop(context, "logout");
                          },
                        ),
                      ),
                    ],
                    onSelected: (String value) {
                      switch (value) {
                        case "settings":
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => SettingsPage(
                                      controller: myController,
                                      analytics: widget.analytics)));
                          break;
                        case "logout":
                          ApplicationState().signOut();
                          myController.cleanUp!();
                          break;
                        default:
                      }
                    },
                  )
                ],
              ),
              body: buildPageView(),
              bottomNavigationBar: BottomNavigationBar(
                  currentIndex: currentIndex,
                  backgroundColor: Colors.blue,
                  selectedItemColor: Colors.white,
                  onTap: onItemTap,
                  items: buildBottomNavBarItems()),
            ));
          } else {
            return Scaffold(
                appBar: AppBar(
                  title: Text(widget.title),
                ),
                body: Consumer<ApplicationState>(
                  builder: (context, appState, _) => Authentication(
                    email: appState.email,
                    loginState: appState.loginState,
                    startLoginFlow: appState.startLoginFlow,
                    verifyEmail: appState.verifyEmail,
                    signInWithEmailAndPassword:
                        appState.signInWithEmailAndPassword,
                    cancelRegistration: appState.cancelRegistration,
                    registerAccount: appState.registerAccount,
                    signOut: appState.signOut,
                  ),
                ));
          }
        },
      ),
    );
  }
}
