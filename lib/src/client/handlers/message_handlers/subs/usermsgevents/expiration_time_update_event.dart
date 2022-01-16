import 'dart:convert';

import 'package:mildly_encrypted_package/mildly_encrypted_package.dart';
import 'package:mildly_encrypted_package/src/client/data/message_storage.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/message_handler.dart';
import 'package:mildly_encrypted_package/src/logging/ELog.dart';
import 'package:mildly_encrypted_package/src/utils/json_validator.dart';
import 'package:uuid/uuid.dart';

class ExpirationTimeUpdateEvent implements MessageHandler {
  @override
  bool check(String message, String from, {String? keyID}) {
    return JSONValidate.isValidJSON(message, requiredKeys: [ClientComponent.EXPIRATION_UPDATE_MS]);
  }

  @override
  String getHandlerName() {
    return "Message Expiration Time Update Event";
  }

  @override
  void handle(String message, String from, {String? keyID}) async {
    Map map = jsonDecode(message);
    int time = map[ClientComponent.EXPIRATION_UPDATE_MS];
    ClientManagement management = await ClientManagement.getInstance();
    ClientUser? user = keyID != null ? await management.getGroupChat(keyID) : await management.getUser(from);
    if (user == null) {
      ELog.e('Cannot find chat to update expiration time of.');
      return;
    }
    await user.setChatExpirationTime(time, sendUpdate: false);
  }
}
