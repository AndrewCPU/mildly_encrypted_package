import 'dart:convert';

import 'package:mildly_encrypted_package/mildly_encrypted_package.dart';
import 'package:mildly_encrypted_package/src/client/cutil/client_components.dart';
import 'package:mildly_encrypted_package/src/client/data/client_key_manager.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/message_handler.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientGroupChat.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientManagement.dart';
import 'package:mildly_encrypted_package/src/utils/json_validator.dart';

class LeaveGroupChatEvent implements MessageHandler {
  @override
  bool check(String message, String from, {String? keyID}) {
    return JSONValidate.isValidJSON(message, requiredKeys: [ClientComponent.LEAVE_GROUP]) && keyID != null;
  }

  @override
  String getHandlerName() {
    return "Leave Group Chat Event";
  }

  @override
  void handle(String message, String from, {String? keyID}) async {
    Map map = jsonDecode(message);
    EncryptedClient client = EncryptedClient.getInstance()!;
    int leaveTime = map[ClientComponent.LEAVE_GROUP];
    await ClientKeyManager().removeUserFromGroupChat(client.serverUrl, keyID!, from, leaveTime);
    ClientGroupChat chat = ((await (await ClientManagement.getInstance()).getGroupChat(keyID))!);
    await chat.init();
  }
}
