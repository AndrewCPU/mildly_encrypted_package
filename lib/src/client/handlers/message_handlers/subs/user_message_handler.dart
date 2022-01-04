import 'dart:convert';

import 'package:mildly_encrypted_package/mildly_encrypted_package.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/subs/usermsgevents/chat_events/group/add_to_group_event.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/subs/usermsgevents/chat_events/group/group_image_update_event.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/subs/usermsgevents/chat_events/group/group_name_update_event.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/subs/usermsgevents/chat_events/group/leave_group_chat_event.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/subs/usermsgevents/chat_events/reaction_handler.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/subs/usermsgevents/chat_events/read_status_handler.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/subs/usermsgevents/chat_events/typing_handler.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/subs/usermsgevents/chat_message_event.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/subs/usermsgevents/full_key_exchange_complete_event.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/subs/usermsgevents/group_chat_invite_event.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/subs/usermsgevents/message_update_event.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/subs/usermsgevents/name_update_event.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/subs/usermsgevents/profile_picture_update_event.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/subs/usermsgevents/rand_int_event.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientGroupChat.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientManagement.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientUser.dart';
import 'package:mildly_encrypted_package/src/client/objs/ServerObject.dart';
import 'package:mildly_encrypted_package/src/client/objs/encryption_pack.dart';
import 'package:mildly_encrypted_package/src/logging/ELog.dart';
import 'package:mildly_encrypted_package/src/utils/json_validator.dart';
import 'package:mildly_encrypted_package/src/utils/magic_nums.dart';

import '../message_handler.dart';

class UserMessageHandler implements MessageHandler {
  ServerObject serverObject;

  UserMessageHandler(this.serverObject);

  @override
  bool check(String message, String from, {String? keyID}) {
    return (JSONValidate.isValidJSON(message, requiredKeys: [MagicNumber.FROM_USER, MagicNumber.MESSAGE_COMPILATION]));
  }

  @override
  void handle(String message, String from, {String? keyID}) async {
    ClientUser? user;
    if (keyID != null) {
      user = ((await (await ClientManagement.getInstance()).getGroupChat(keyID)));

      ELog.i("Using group chat key to decrypt.");
    } else {
      user = ((await (await ClientManagement.getInstance()).getUser(from)));
      ELog.i("Using individual user key to decrypt.");
    }
    if (user == null) {
      ELog.e("Received an encrypted message from $from, but we cannot find the user data.");
      return;
    }
    Map map = jsonDecode(message);
    String decryptedMessage = user.decryptFromUser((map[MagicNumber.MESSAGE_COMPILATION] as List).cast<String>());

    List<MessageHandler> handlers = [
      ChatMessageEvent(user),
      RandIntEvent(user),
      NameUpdateEvent(user),
      ProfilePictureUpdateEvent(user),
      MessageUpdateEvent(),
      GroupChatInviteEvent(),
      LeaveGroupChatEvent(),
      AddToGroupEvent(),
      GroupImageUpdateEvent(),
      GroupNameUpdateEvent(),
      TypingHandler(),
      KeyExchangeCompleteEvent(),
    ];

    for (MessageHandler handler in handlers) {
      if (handler.check(decryptedMessage, from, keyID: keyID)) {
        ELog.i("User Message Handler passing it to " + handler.getHandlerName());
        handler.handle(decryptedMessage, from, keyID: keyID);
        return;
      }
    }
    ELog.e("Received a message we didn't know how to handle! ($decryptedMessage)");
  }

  @override
  String getHandlerName() {
    return "User Message Handler";
  }
}
