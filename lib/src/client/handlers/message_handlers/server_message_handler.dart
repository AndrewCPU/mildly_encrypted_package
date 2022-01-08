import 'dart:convert';

import 'package:mildly_encrypted_package/mildly_encrypted_package.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/message_handler.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/subs/key_exchange_handler.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/subs/online_status_handler.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/subs/user_message_handler.dart';
import 'package:mildly_encrypted_package/src/client/objs/ServerObject.dart';
import 'package:mildly_encrypted_package/src/logging/ELog.dart';
import 'package:mildly_encrypted_package/src/utils/encryption_util.dart';
import 'package:mildly_encrypted_package/src/utils/json_validator.dart';
import 'package:mildly_encrypted_package/src/utils/magic_nums.dart';

class ServerMessageHandler {
  ServerObject serverObject;

  List<MessageHandler> handlers = [];

  ServerMessageHandler(this.serverObject) {
    handlers.add(KeyExchangeHandler(serverObject));
    handlers.add(UserMessageHandler(serverObject));
    handlers.add(OnlineStatusHandler());
  }

  void handle(EncryptedClient client, String data) async{
    print(data);
    if (!JSONValidate.isValidJSON(data, requiredKeys: [MagicNumber.MESSAGE_COMPILATION])) {
      ELog.e("Server message handler was passed invalid data.");
      return;
    }

    Map encryptedMap = jsonDecode(data);
    String decodedComp = await EncryptionUtil.decryptParts((encryptedMap[MagicNumber.MESSAGE_COMPILATION] as List).cast<String>(), serverObject.encrypter);
    Map map = jsonDecode(decodedComp);
    String from = map[MagicNumber.FROM_USER] ?? 'server';
    String? keyID;
    if (map.containsKey(MagicNumber.KEY_ID)) {
      keyID = map[MagicNumber.KEY_ID];
    }
    for (MessageHandler handler in handlers) {
      if (handler.check(decodedComp, from, keyID: keyID)) {
        ELog.i("Received a message for ${handler.getHandlerName()}");
        handler.handle(decodedComp, from, keyID: keyID);
        return;
      }
    }
    ELog.i("No one was able to take the message");
  }
}
