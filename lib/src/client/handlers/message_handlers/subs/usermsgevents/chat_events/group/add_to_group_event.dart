import 'dart:convert';

import 'package:mildly_encrypted_package/mildly_encrypted_package.dart';
import 'package:mildly_encrypted_package/src/client/cutil/client_components.dart';
import 'package:mildly_encrypted_package/src/client/data/client_key_manager.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/message_handler.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientGroupChat.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientManagement.dart';
import 'package:mildly_encrypted_package/src/logging/ELog.dart';
import 'package:mildly_encrypted_package/src/utils/json_validator.dart';

class AddToGroupEvent implements MessageHandler {
  @override
  bool check(String message, String from, {String? keyID}) {
    return JSONValidate.isValidJSON(message, requiredKeys: [ClientComponent.ADD_TO_GROUP]) && keyID != null;
  }

  @override
  String getHandlerName() {
    return "Group Chat Add Event";
  }

  @override
  void handle(String message, String from, {String? keyID}) async {
    Map map = jsonDecode(message);
    String groupChatID = keyID!;
    EncryptedClient client = EncryptedClient.getInstance()!;
    List<String> members = (await ClientKeyManager().getGroupChatMembers(client.serverUrl, groupChatID))!;
    members.add(map[ClientComponent.ADD_TO_GROUP]);

    if (!(await ClientKeyManager().doesContactExist(client.serverUrl, map[ClientComponent.ADD_TO_GROUP]))) {
      await ClientKeyManager().createContact(client.serverUrl, map[ClientComponent.ADD_TO_GROUP]);
    }

    await ClientKeyManager().setGroupChatMembers(client.serverUrl, groupChatID, members);
    ClientGroupChat? chat = ((await (await ClientManagement.getInstance()).getGroupChat(keyID)));
    if (chat == null) {
      ELog.e("Cannot reinit group. Can't find it!");
      return;
    }
    await chat.init();
  }
}
