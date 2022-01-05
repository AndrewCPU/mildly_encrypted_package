import 'dart:convert';

import 'package:mildly_encrypted_package/mildly_encrypted_package.dart';
import 'package:mildly_encrypted_package/src/client/cutil/client_components.dart';
import 'package:mildly_encrypted_package/src/client/cutil/notification_registry.dart';
import 'package:mildly_encrypted_package/src/client/data/message_storage.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/message_handler.dart';
import 'package:mildly_encrypted_package/src/logging/ELog.dart';
import 'package:mildly_encrypted_package/src/utils/json_validator.dart';

class ReactionHandler implements MessageHandler {
  @override
  bool check(String message, String from, {String? keyID}) {
    //we need a message id to update, and a message update value
    return JSONValidate.isValidJSON(message, requiredKeys: [ClientComponent.ADD_REACTION]) ||
        JSONValidate.isValidJSON(message, requiredKeys: [ClientComponent.REMOVE_REACTION]);
  }

  @override
  String getHandlerName() {
    return "Reaction Message Update Event";
  }

  @override
  Future<void> handle(String message, String from, {String? keyID}) async {
    Map map = jsonDecode(message);
    String messageUuid = map[ClientComponent.MESSAGE_UUID];

    ClientUser updateMe;
    if (keyID != null) {
      updateMe = (await (await ClientManagement.getInstance()).getGroupChat(keyID))!;
    } else {
      updateMe = (await (await ClientManagement.getInstance()).getUser(from))!;
    }

    if (map.containsKey(ClientComponent.ADD_REACTION)) {
      String reaction = map[ClientComponent.ADD_REACTION];
      await updateMe.acceptReactionRemoval(from, messageUuid, reaction);
      await updateMe.acceptReactionAddition(from, messageUuid, reaction);
    } else if (map.containsKey(ClientComponent.REMOVE_REACTION)) {
      String reaction = map[ClientComponent.REMOVE_REACTION];
      await updateMe.acceptReactionRemoval(from, messageUuid, reaction);
    }

    UpdateNotificationRegistry.getInstance().messageUpdate(updateMe, messageUuid);
  }
}
