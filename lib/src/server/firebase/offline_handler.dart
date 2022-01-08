import 'dart:convert';
import 'dart:io';

import 'package:googleapis_auth/auth_io.dart';
import "package:http/http.dart" as http;

import '../../logging/ELog.dart';

class OfflineHandler {
  static final OfflineHandler _instance = OfflineHandler._internal();
  OfflineHandler._internal();
  factory OfflineHandler() {
    return _instance;
  }

  String? notificationKey;

  static Map<dynamic, dynamic> bodyBuilder({required String targetToken, String? notificationBody, String? notificationTitle, Map? data}) {
    Map<dynamic, dynamic> body = {};
    body['message'] = {};
    Map messageBody = (body['message']);
    messageBody['webpush'] = {
      "headers": {"Urgency": "high"}
    };
    messageBody['android'] = {"priority": "high"};
    messageBody['token'] = targetToken;
    if (notificationBody != null || notificationTitle != null) {
      messageBody['notification'] = {};
    }
    if (notificationBody != null) {
      messageBody['notification']['body'] = notificationBody;
    }
    if (notificationTitle != null) {
      messageBody['notification']['title'] = notificationTitle;
    }
    if (data != null) {
      messageBody['data'] = data;
    }
    return body;
  }

  void sendNotification(Map notificationBody) async {
    if (notificationKey == null) {
      getAuthBearer(() {
        sendNotification(notificationBody);
      });
      return;
    }

    var body = json.encode(notificationBody);
    var headers = {"Content-Type": "application/json; charset=utf-8", "Authorization": "Bearer " + notificationKey!};
    var response = await http.post(
      Uri.parse("https://fcm.googleapis.com/v1/projects/dial-87d46/messages:send"),
      headers: headers,
      body: body,
    );
    if (response.statusCode != 200) {
      if (response.statusCode == 404) {
        ELog.e("Unable to send push notification.");
        return;
      }
      getAuthBearer(() {
        sendNotification(notificationBody);
      });
      print(response.body);
      ELog.e("Invalid auth code! Getting a new one.");
      return;
    }
    ELog.i("Sending a push notification.");
    return;
  }

  Future<AccessCredentials> _obtainCredentials(Map credentialMap) async {
    var accountCredentials = ServiceAccountCredentials.fromJson(credentialMap);
    var scopes = ["https://www.googleapis.com/auth/firebase.messaging"];

    var client = http.Client();
    AccessCredentials credentials = await obtainAccessCredentialsViaServiceAccount(accountCredentials, scopes, client);

    client.close();
    return credentials;
  }

  void getAuthBearer(Function() finishedCallback) {
    File('.pn/serviceAccountKey.json').readAsString().then((String contents) {
      Map credentialMap = jsonDecode(contents);
      () async {
        notificationKey = (await _obtainCredentials(credentialMap)).accessToken.data;
        finishedCallback();
      }.call();
    });
  }
}
