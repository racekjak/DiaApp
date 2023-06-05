// ignore_for_file: use_build_context_synchronously

import 'package:encrypted_shared_preferences/encrypted_shared_preferences.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:js_flutter/pages/MainPage.dart';
import 'package:js_flutter/services/apiController.dart';
import 'package:js_flutter/services/aplicationstate.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage(
      {Key? key, required this.controller, required this.analytics})
      : super(key: key);
  final HomePageController controller;
  final FirebaseAnalytics analytics;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final ApiController apiController = ApiController();
  final _formKey = GlobalKey<FormState>();
  final _goalInput = GlobalKey<FormState>();
  final dailyGoalController = TextEditingController();
  final idController = TextEditingController();
  final pwdController = TextEditingController();
  final EncryptedSharedPreferences encryptedSharedPreferences =
      EncryptedSharedPreferences();
  String? id;
  String? pwd;

  @override
  void initState() {
    super.initState();

    setUp();
  }

  void setUp() async {
    idController.text = await encryptedSharedPreferences.getString("id");
    dailyGoalController.text =
        await encryptedSharedPreferences.getString("dailyGoal");
  }

  Widget formBuilder() {
    return (Form(
        key: _formKey,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 30),
          child: Column(
            children: <Widget>[
              TextFormField(
                controller: idController,
                decoration:
                    const InputDecoration(hintText: 'Login ID', filled: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Zadejte ID!';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: pwdController,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration:
                    const InputDecoration(hintText: 'Password', filled: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Zadejte Heslo!';
                  }
                  return null;
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                mainAxisSize: MainAxisSize.max,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      bool valid =
                          await apiController.validateDexcomCredentials(
                              idController.text.trim(), pwdController.text);
                      if (_formKey.currentState!.validate() && valid) {
                        await encryptedSharedPreferences
                            .setString('id', idController.text.trim())
                            .then((bool success) async {
                          if (success) {
                            await encryptedSharedPreferences
                                .getString('id')
                                .then((String _value) {
                              setState(() {
                                id = _value;
                              });
                            });
                          }
                        });
                        await encryptedSharedPreferences
                            .setString('pwd', pwdController.text)
                            .then((bool success) async {
                          if (success) {
                            await encryptedSharedPreferences
                                .getString('pwd')
                                .then((String _value) {
                              setState(() {
                                pwd = _value;
                              });
                            });
                          }
                        });
                        Navigator.of(context).pop();
                        if (id != null && pwd != null) {
                          widget.controller.setUp!();
                        }
                      } else {
                        pwdController.clear();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Špatné přihlašovací údaje'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    child: const Text('Uložit'),
                  ),
                  ElevatedButton(
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () {
                      idController.clear();
                      widget.controller.cleanUp!();
                    },
                    child: const Text('Smazat'),
                  ),
                ],
              ),
            ],
          ),
        )));
  }

  Widget dailyGoalInput() {
    return (Form(
      key: _goalInput,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 30),
        child: Column(
          children: [
            Container(
                margin: const EdgeInsets.only(bottom: 20, top: 0),
                child: const Center(
                  child: Text(
                    "Základní hodnota denního cíle je nastavena na 150 bodů",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )),
            TextFormField(
              controller: dailyGoalController,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly
              ],
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: '210', filled: true),
              validator: (value) {
                if (value == null ||
                    value.isEmpty ||
                    int.parse(value) > 288 ||
                    int.parse(value) < 1) {
                  return 'Zadejte číslo v rozmezí 1 - 288';
                }
                return null;
              },
            ),
            ElevatedButton(
              onPressed: () {
                bool valid = _goalInput.currentState!.validate();
                if (valid) {
                  FocusNode currentFocus = FocusScope.of(context);
                  FocusScope.of(context).unfocus();
                  encryptedSharedPreferences
                      .setString("dailyGoal", dailyGoalController.text.trim())
                      .then((value) {
                    if (value) {
                      widget.controller.setPrefs!();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Denní cíl byl nastaven'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      widget.analytics.logEvent(name: 'setGoal', parameters: {
                        "points": dailyGoalController.text.trim()
                      });
                    }
                  });
                }
              },
              child: const Text("Nastavit cíl"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            )
          ],
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return (Scaffold(
      appBar: AppBar(
        title: const Text("Nastavení"),
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                value: "logout",
                child: TextButton.icon(
                  label: const Text("Odhlásit se"),
                  icon: const Icon(Icons.logout),
                  onPressed: () {
                    Navigator.pop(context, "logout");
                    ApplicationState().signOut();
                    widget.controller.cleanUp!();
                  },
                ),
              )
            ],
          )
        ],
      ),
      body: ListView(
        children: [
          ExpansionTile(
            title: const Text("Dexcom Přihlášení"),
            children: [formBuilder()],
          ),
          ExpansionTile(
            title: const Text("Nastavení denního cíle"),
            children: [dailyGoalInput()],
          )
        ],
      ),
    ));
  }
}
