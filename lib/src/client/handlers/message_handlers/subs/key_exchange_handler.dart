import 'dart:convert';

import 'package:encrypt/encrypt.dart';
import 'package:mildly_encrypted_package/src/client/data/client_key_manager.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/message_handler.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientManagement.dart';
import 'package:mildly_encrypted_package/src/client/objs/EncryptedKeyExchanger.dart';
import 'package:mildly_encrypted_package/src/client/objs/ServerObject.dart';
import 'package:mildly_encrypted_package/src/logging/ELog.dart';
import 'package:mildly_encrypted_package/src/utils/crypto_utils.dart';
import 'package:mildly_encrypted_package/src/utils/encryption_util.dart';
import 'package:mildly_encrypted_package/src/utils/json_validator.dart';
import 'package:mildly_encrypted_package/src/utils/magic_nums.dart';

import 'package:pointycastle/asymmetric/api.dart' as rsa;

import '../../../client.dart';

class KeyExchangeHandler implements MessageHandler {
  ServerObject serverObject;

  KeyExchangeHandler(this.serverObject);

  @override
  bool check(String message, String from, {String? keyID}) {
    return (JSONValidate.isValidJSON(message, requiredKeys: [MagicNumber.FROM_USER, MagicNumber.ENCRYPTED_KEY_EXCHANGE]));
  }

  @override
  void handle(String message, String from, {String? keyID}) async {
    print(message);
    EncryptedClient client = EncryptedClient.getInstance()!;
    Map map = jsonDecode(message);
    List<String> encryptedPieces = ((map[MagicNumber.ENCRYPTED_KEY_EXCHANGE] as List).cast<String>());
    rsa.RSAPrivateKey myPrivateKeyKey;
    bool doWeHaveContactAlready = false;
    if (await ClientKeyManager().doesContactExist(client.serverUrl, from) && await ClientKeyManager().haveWeSentKeys(client.serverUrl, from)) {
      myPrivateKeyKey = ((await (await ClientManagement.getInstance()).getUser(from))!).privateKey!;
      //we have sent our keys to the user so we can assume they will be using our public key to respond with their key exchange
      doWeHaveContactAlready = true;
    } else {
      myPrivateKeyKey = CryptoUtils.rsaPrivateKeyFromPem(EncryptedClient.getInstance()!.qrPrivate);
    }

    Encrypter encrypter = Encrypter(RSA(privateKey: myPrivateKeyKey));
    String decryptedMessage = await EncryptionUtil.decryptParts(encryptedPieces, encrypter);

    map = jsonDecode(decryptedMessage);

    String remotePublicKey = map[MagicNumber.ENCRYPTED_KEY_EXCHANGE];

    if (doWeHaveContactAlready) {
      if (await ClientKeyManager().haveWeReceivedKeys(client.serverUrl, from)) {
        ELog.i("$from tried to send a new key, overriding their old one. Disallowed.");
        return;
      } else {
        await ClientKeyManager().updateContact(client.serverUrl, from, remotePublic: remotePublicKey);
        (await (await (await ClientManagement.getInstance()).getUser(from))!.init());
        if (await ClientKeyManager().hasAllValidKeys(client.serverUrl, from) && !(await ClientKeyManager().isRandIntDone(client.serverUrl, from))) {
          ELog.i("Encrypted key exchange has been completed with $from");
          await (await (await ClientManagement.getInstance()).getUser(from))!.sendFileEncryptionKeyPart();
        }
        //we have sent keys, and we have received keys. should be good to proceed.
      }
    } else {
      await ClientKeyManager().createContact(client.serverUrl, from, remotePublic: remotePublicKey);
      // this was the initial transaction, we should send over our keys with this users new public key.
      await EncryptedKeyExchanger.exchangeKey(from, remotePublicKey);
      ELog.i("Encrypted key exchange has been completed with $from. Waiting on file encryption keys.");
    }

    // old below
    //
    // if (await ClientKeyManager().doesContactExist(serverIP, from)) {
    //   // if the contact exists, we've sent keys.
    //   if (await ClientKeyManager().haveWeReceivedKeys(serverIP, from)) {
    //     ELog.e("Received message attempting to override an existing remote public key. Denying override.");
    //   } else {
    //     await ClientKeyManager().updateContact(serverIP, from, remotePublic: map[MagicNumber.PUBLIC_KEY_DELIM]);
    //   }
    // } else {
    //   await ClientKeyManager().createContact(serverIP, from, remotePublic: map[MagicNumber.PUBLIC_KEY_DELIM]);
    //   await serverObject.exchangeKeys(from);
    // }
    // if (await ClientKeyManager().hasAllValidKeys(serverIP, from)) {
    //   ELog.i("Key exchange complete with $from");
    //   if (!(await ClientKeyManager().isRandIntDone(serverIP, from))) {
    //     ClientUser user = ((await (await ClientManagement.getInstance()).getUser(from)))!;
    //     await user.sendFileEncryptionKeyPart();
    //   }
    // }
  }

  @override
  String getHandlerName() {
    return "Key Exchange Handler";
  }
}
