import 'dart:convert';

import 'package:mildly_encrypted_package/mildly_encrypted_package.dart';
import 'package:mildly_encrypted_package/src/client/cutil/client_components.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/message_handler.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientGroupChat.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientManagement.dart';
import 'package:mildly_encrypted_package/src/logging/ELog.dart';
import 'package:mildly_encrypted_package/src/utils/json_validator.dart';

class GroupNameUpdateEvent implements MessageHandler {
  @override
  bool check(String message, String from, {String? keyID}) {
    return JSONValidate.isValidJSON(message, requiredKeys: [ClientComponent.GROUP_NAME_UPDATE]) && keyID != null;
  }

  @override
  String getHandlerName() {
    return "Group Name Update Event";
  }

  @override
  void handle(String message, String from, {String? keyID}) async {
    Map map = jsonDecode(message);
    String newName = map[ClientComponent.GROUP_NAME_UPDATE];
    ClientGroupChat? group = ((await (await ClientManagement.getInstance()).getGroupChat(keyID!)));

    if (group == null) {
      ELog.e("Cannot find group to update name.");
      return;
    }
    await group.updateUsername(newName);
    await group.init();
    CoreEventRegistry().notify(CoreEventType.NAME_UPDATE, data: from);
  }
}
