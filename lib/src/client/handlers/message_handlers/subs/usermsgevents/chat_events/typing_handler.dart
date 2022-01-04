import 'dart:convert';

import 'package:mildly_encrypted_package/mildly_encrypted_package.dart';
import 'package:mildly_encrypted_package/src/client/cutil/client_components.dart';
import 'package:mildly_encrypted_package/src/client/cutil/notification_registry.dart';
import 'package:mildly_encrypted_package/src/client/data/client_key_manager.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/message_handler.dart';
import 'package:mildly_encrypted_package/src/logging/ELog.dart';
import 'package:mildly_encrypted_package/src/utils/json_validator.dart';

class TypingHandler implements MessageHandler {
  @override
  bool check(String message, String from, {String? keyID}) {
    return JSONValidate.isValidJSON(message, requiredKeys: [ClientComponent.TYPING_INDICATOR]);
  }

  @override
  String getHandlerName() {
    return "Typing Indicator Event";
  }

  @override
  void handle(String message, String from, {String? keyID}) async {
    Map map = jsonDecode(message);
    int timeTyping = map[ClientComponent.TYPING_INDICATOR];
    String chatID = keyID ?? from;
    Map? data = await ClientKeyManager().getUserData(EncryptedClient.getInstance()!.serverUrl, chatID);
    if (data == null) {
      ELog.e("Cannot update user data for typing indicator! Cannot find user in table!");
      return;
    }
    Map typing = {};
    if (data.containsKey('typing')) {
      typing = data['typing'];
    }
    typing[from] = timeTyping;
    data['typing'] = typing;
    await ClientKeyManager().updateContact(EncryptedClient.getInstance()!.serverUrl, chatID, data: data);
    if (keyID != null) {
      UpdateNotificationRegistry.getInstance().typingChange((await (await ClientManagement.getInstance()).getGroupChat(keyID))!);
    } else {
      UpdateNotificationRegistry.getInstance().typingChange((await (await ClientManagement.getInstance()).getUser(from))!);
    }
  }
}
