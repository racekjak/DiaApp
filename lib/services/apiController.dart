// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';

import 'package:encrypted_shared_preferences/encrypted_shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'package:js_flutter/utils/strings.dart';
import 'package:js_flutter/dataTypes/bgReading.dart';

class ApiController {
  http.Client client = http.Client();
  final EncryptedSharedPreferences encryptedSharedPreferences =
      EncryptedSharedPreferences();
  Map<String, String> headers = {
    "accept": "application/json",
    "Content-Type": "application/json",
    //"User-Agent": "Dexcom Share/3.0.2.11 CFNetwork/711.2.23 Darwin/14.0.0"
  };

  Future<bool> validateDexcomCredentials(String id, String pwd) async {
    try {
      const baseUrl = Strings.DEXCOM_BASE_URL_OUS;
      const accountUrl = "$baseUrl/${Strings.DEXCOM_AUTHENTICATE_ENDPOINT}";
      var accountId = await client.post(
        Uri.parse(accountUrl),
        body: jsonEncode({
          "accountName": id,
          "applicationId": Strings.DEXCOM_APPLICATION_ID,
          "password": pwd
        }),
        headers: headers,
      );
      if (accountId.statusCode != 500) {
        encryptedSharedPreferences.setString(
            'accountID', jsonDecode(accountId.body));
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print(e);
      return false;
    }
  }

  Future<String> setSessionID(String id, String pwd) async {
    const baseUrl = Strings.DEXCOM_BASE_URL_OUS;
    const sessionUrl = "$baseUrl/${Strings.DEXCOM_LOGIN_ID_ENDPOINT}";
    var accountId = await encryptedSharedPreferences.getString('accountID');

    if (accountId.isNotEmpty) {
      try {
        var sessionId = await client.post(
          Uri.parse(sessionUrl),
          body: jsonEncode({
            "accountId": accountId,
            "applicationId": Strings.DEXCOM_APPLICATION_ID,
            "password": pwd
          }),
          headers: headers,
        );

        if (sessionId.statusCode != 500) {
          await encryptedSharedPreferences.setString(
              'sessionID', jsonDecode(sessionId.body));
          return (jsonDecode(sessionId.body));
        } else {
          return "";
        }
      } catch (e) {
        print(e);
        return "";
      }
    } else {
      await validateDexcomCredentials(id, pwd).then((value) {
        if (value) {
          setSessionID(id, pwd).then((value) {
            return value;
          });
        } else {
          return "";
        }
      }).catchError((err) {
        print(err);
      });
    }

    return "";
  }

  Future<BgReading?> getBG(String id, String pwd) async {
    const baseUrl = Strings.DEXCOM_BASE_URL_OUS;
    const bgUrl = "$baseUrl/${Strings.DEXCOM_GLUCOSE_READINGS_ENDPOINT}";
    var sessionId = await encryptedSharedPreferences.getString('sessionID');
    BgReading? reading;

    if (sessionId.isNotEmpty) {
      try {
        var bgReading = await client.post(Uri.parse(bgUrl),
            headers: headers,
            body: jsonEncode({
              "sessionId": sessionId,
              "minutes": 1440,
              "maxCount": 1,
            }));
        if (bgReading.statusCode != 500) {
          var value = await jsonDecode(bgReading.body)[0]["Value"];
          var trendText = await jsonDecode(bgReading.body)[0]['Trend'];
          trendText = Strings.DEXCOM_TREND_ARROWS[
              Strings.DEXCOM_TREND_DIRECTIONS[trendText]!.toInt()];
          var timeStamp = await jsonDecode(bgReading.body)[0]['WT'];
          timeStamp = num.parse((timeStamp.substring(5, timeStamp.length - 1)));
          double mmol = double.parse((value * 0.0555).toStringAsFixed(1));
          BgReading reading = BgReading(
              mmol, trendText, DateTime.fromMillisecondsSinceEpoch(timeStamp));
          return (reading);
        } else {
          await setSessionID(id, pwd).then((value) async {
            if (value.isNotEmpty) {
              await getBG(id, pwd).then((value) {
                reading = value;
              });
            } else {
              return reading;
            }
          });
        }
      } catch (e) {
        print(e);
        return reading;
      }
    } else {
      await setSessionID(id, pwd).then((value) async {
        if (value.isNotEmpty) {
          await getBG(id, pwd).then((value) async {
            reading = value;
          });
        } else {
          return reading;
        }
      });
    }
    return reading;
  }

  Future<List<BgReading>?> getXLastBGs(
      String id, String pwd, int missed) async {
    const baseUrl = Strings.DEXCOM_BASE_URL_OUS;
    const bgUrl = "$baseUrl/${Strings.DEXCOM_GLUCOSE_READINGS_ENDPOINT}";
    var sessionId = await encryptedSharedPreferences.getString('sessionID');
    List<BgReading> xBgs = [];

    if (sessionId.isNotEmpty) {
      try {
        var bgReading = await client.post(Uri.parse(bgUrl),
            headers: headers,
            body: jsonEncode({
              "sessionId": sessionId,
              "minutes": 1440,
              "maxCount": missed,
            }));
        if (bgReading.statusCode != 500) {
          for (var i = 0; i < jsonDecode(bgReading.body).length; i++) {
            var value = await jsonDecode(bgReading.body)[i]["Value"];
            var timeStamp = await jsonDecode(bgReading.body)[i]['WT'];
            timeStamp =
                num.parse((timeStamp.substring(5, timeStamp.length - 1)));
            var trendText = await jsonDecode(bgReading.body)[i]['Trend'];
            trendText = Strings.DEXCOM_TREND_ARROWS[
                Strings.DEXCOM_TREND_DIRECTIONS[trendText]!.toInt()];
            var mmolString = (value * 0.0555).toStringAsFixed(1).toString();
            double mmol = double.parse(mmolString);
            DateTime time = DateTime.fromMillisecondsSinceEpoch(timeStamp);
            xBgs.add(BgReading(mmol, trendText, time));
          }
          return xBgs;
        }
      } catch (e) {
        print(e);
        return xBgs;
      }
    } else {
      await setSessionID(id, pwd).then((value) {
        if (value.isNotEmpty) {
          getXLastBGs(id, pwd, missed).then((value) {
            return value;
          });
        } else {
          return xBgs;
        }
      });
    }
    return xBgs;
  }

  Future<String?> getDaysBG(String id, String pwd, int hours) async {
    const baseUrl = Strings.DEXCOM_BASE_URL_OUS;
    const bgUrl = "$baseUrl/${Strings.DEXCOM_GLUCOSE_READINGS_ENDPOINT}";
    var sessionId = await encryptedSharedPreferences.getString('sessionID');

    if (sessionId.isEmpty) {
      await setSessionID(id, pwd);
    }
    var bg = await client.post(Uri.parse(bgUrl),
        headers: headers,
        body: jsonEncode({
          "sessionId": sessionId,
          "minutes": hours * 60,
          "maxCount": hours * 12,
        }));

    if (bg.statusCode == 500) {
      await setSessionID(id, pwd).whenComplete(() => getDataSource(hours));
    } else {
      return bg.body;
    }
    return null;
  }

  Future<List<BgReading>?> getDataSource(int hours) async {
    var id = await encryptedSharedPreferences.getString('id');
    var pwd = await encryptedSharedPreferences.getString('pwd');
    var data = await getDaysBG(id, pwd, hours);
    List<BgReading> bgs = [];
    if (data != null) {
      for (var i = 0; i < jsonDecode(data).length; i++) {
        var value = await jsonDecode(data)[i]["Value"];
        var timeStamp = await jsonDecode(data)[i]['WT'];
        timeStamp = num.parse((timeStamp.substring(5, timeStamp.length - 1)));
        var trendText = await jsonDecode(data)[i]['Trend'];
        trendText = Strings.DEXCOM_TREND_ARROWS[
            Strings.DEXCOM_TREND_DIRECTIONS[trendText]!.toInt()];
        var mmolString = (value * 0.0555).toStringAsFixed(1).toString();
        double mmol = double.parse(mmolString);
        DateTime time = DateTime.fromMillisecondsSinceEpoch(timeStamp);
        bgs.add(BgReading(mmol, trendText, time));
      }
      return (bgs);
    }
    return null;
  }
}
