import 'dart:convert';

import 'package:mildly_encrypted_package/src/client/cutil/client_components.dart';
import 'package:mildly_encrypted_package/src/client/data/client_key_manager.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/message_handler.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientManagement.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientUser.dart';
import 'package:mildly_encrypted_package/src/logging/ELog.dart';
import 'package:mildly_encrypted_package/src/utils/json_validator.dart';

import '../../../../client.dart';

class RandIntEvent implements MessageHandler {
  ClientUser user;

  RandIntEvent(this.user);

  @override
  bool check(String message, String from, {String? keyID}) {
    return JSONValidate.isValidJSON(message, requiredKeys: [ClientComponent.RAND_INT]);
  }

  @override
  String getHandlerName() {
    return "File Encryption Event";
  }

  @override
  void handle(String message, String from, {String? keyID}) async {
    Map map = jsonDecode(message);
    int otherRandInt = map[ClientComponent.RAND_INT];
    var serverIP = EncryptedClient.getInstance()!.serverUrl;
    await ClientKeyManager().updateContact(serverIP, from, remoteRandInt: otherRandInt);
    if (!(await ClientKeyManager().haveWeSentRandInt(serverIP, from))) {
      await user.sendFileEncryptionKeyPart();
      if ((await ClientKeyManager().haveWeReceivedRandInt(serverIP, from))) {
        ELog.i("File encryption key exchange complete!");
        (await (await ClientManagement.getInstance()).getUser(from))!
            .sendDataPacket(jsonEncode({ClientComponent.KEY_EXCHANGE_COMPLETE: DateTime.now().millisecondsSinceEpoch}));
      }
    } else {
      ELog.i("File encryption key exchange complete!");
      (await (await ClientManagement.getInstance()).getUser(from))!
          .sendDataPacket(jsonEncode({ClientComponent.KEY_EXCHANGE_COMPLETE: DateTime.now().millisecondsSinceEpoch}));
    }
  }
}
