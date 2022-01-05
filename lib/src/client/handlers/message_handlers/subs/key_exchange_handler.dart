import 'dart:convert';

import 'package:mildly_encrypted_package/mildly_encrypted_package.dart';
import 'package:mildly_encrypted_package/src/client/data/client_key_manager.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/message_handler.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientManagement.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientUser.dart';
import 'package:mildly_encrypted_package/src/client/objs/ServerObject.dart';
import 'package:mildly_encrypted_package/src/logging/ELog.dart';
import 'package:mildly_encrypted_package/src/utils/json_validator.dart';
import 'package:mildly_encrypted_package/src/utils/magic_nums.dart';

class KeyExchangeHandler implements MessageHandler {
  ServerObject serverObject;

  KeyExchangeHandler(this.serverObject);

  @override
  bool check(String message, String from, {String? keyID}) {
    return (JSONValidate.isValidJSON(message, requiredKeys: [MagicNumber.FROM_USER, MagicNumber.PUBLIC_KEY_DELIM]));
  }

  @override
  void handle(String message, String from, {String? keyID}) async {
    print(message);

    Map map = jsonDecode(message);
    var serverIP = EncryptedClient.getInstance()!.serverUrl;
    if (await ClientKeyManager().doesContactExist(serverIP, from)) {
      // if the contact exists, we've sent keys.
      if (await ClientKeyManager().haveWeReceivedKeys(serverIP, from)) {
        ELog.e("Received message attempting to override an existing remote public key. Denying override.");
      } else {
        await ClientKeyManager().updateContact(serverIP, from, remotePublic: map[MagicNumber.PUBLIC_KEY_DELIM]);
      }
    } else {
      await ClientKeyManager().createContact(serverIP, from, remotePublic: map[MagicNumber.PUBLIC_KEY_DELIM]);
      await serverObject.exchangeKeys(from);
    }
    if (await ClientKeyManager().hasAllValidKeys(serverIP, from)) {
      ELog.i("Key exchange complete with $from");
      if (!(await ClientKeyManager().isRandIntDone(serverIP, from))) {
        ClientUser user = ((await (await ClientManagement.getInstance()).getUser(from)))!;
        await user.sendFileEncryptionKeyPart();
      }
    }
  }

  @override
  String getHandlerName() {
    return "Key Exchange Handler";
  }
}
