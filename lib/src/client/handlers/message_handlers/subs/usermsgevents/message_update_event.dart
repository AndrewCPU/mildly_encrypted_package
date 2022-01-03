import 'dart:convert';

import 'package:mildly_encrypted_package/src/client/cutil/client_components.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/message_handler.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/subs/usermsgevents/chat_events/reaction_handler.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/subs/usermsgevents/chat_events/read_status_handler.dart';
import 'package:mildly_encrypted_package/src/logging/ELog.dart';
import 'package:mildly_encrypted_package/src/utils/json_validator.dart';

class MessageUpdateEvent implements MessageHandler {
  @override
  bool check(String message, String from, {String? keyID}) {
    //we need a message id to update, and a message update value
    return JSONValidate.isValidJSON(message, requiredKeys: [ClientComponent.MESSAGE_UUID, ClientComponent.MESSAGE_UPDATE]);
  }

  @override
  String getHandlerName() {
    return "Message Update Event";
  }

  @override
  void handle(String message, String from, {String? keyID}) {
    Map map = jsonDecode(message);
    String messageUpdateType = map[ClientComponent.MESSAGE_UPDATE];
    if (messageUpdateType == ClientComponent.MESSAGE_UPDATE_VAL_READ) {
      ELog.i("Message update handler passing it to Read Status Handler");
      ReadStatusHandler().handle(message, from, keyID: keyID);
    } else if (messageUpdateType == ClientComponent.MESSAGE_UPDATE_VAL_REACTION) {
      ReactionHandler().handle(message, from, keyID: keyID);
      ELog.i("Message update handler passing it to Reaction Handler");
    }
  }
}
