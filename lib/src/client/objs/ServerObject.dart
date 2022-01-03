import 'dart:convert';

import 'package:encrypt/encrypt.dart';

import '../../utils/crypto_utils.dart';
import '../../utils/encryption_util.dart';
import '../../utils/magic_nums.dart';
import '../client.dart';
import '../data/client_key_manager.dart';
import 'ClientUser.dart';
import 'package:pointycastle/asymmetric/api.dart' as rsa;
import 'package:pointycastle/api.dart' as asym;

class ServerObject {
  static Future<ServerObject> getInstance(EncryptedClient client) async {
    ServerObject obj = ServerObject(client);
    await obj._init();
    return obj;
  }

  late String uuid;
  late EncryptedClient client;
  late Encrypter encrypter;

  late rsa.RSAPublicKey? remoteKey;
  late rsa.RSAPrivateKey? privateKey;

  ServerObject(this.client) {
    uuid = 'server';
  }

  void _createEncrypter() {
    encrypter = EncryptionUtil.createEncrypter(remoteKey, privateKey);
  }

  Future<void> _init() async {
    remoteKey =
        await ClientKeyManager().getRSARemotePublicKey(client.serverUrl, uuid);
    privateKey =
        await ClientKeyManager().getRSAPrivateKey(client.serverUrl, uuid);
    _createEncrypter();
  }

  Future<void> refreshKeys() async {
    await _init();
  }

  Future<void> sendMessage(String message) async {
    List<String> encryptedBlock =
        EncryptionUtil.toEncryptedPieces(message, encrypter);
    Map m = {MagicNumber.MESSAGE_COMPILATION: encryptedBlock};
    client.getChannel()!.sink.add(jsonEncode(m));
  }

  Future<void> exchangeKeys(String toUser) async {
    asym.AsymmetricKeyPair keys = CryptoUtils.generateRSAKeyPair();
    String public =
        CryptoUtils.encodeRSAPublicKeyToPem(keys.publicKey as rsa.RSAPublicKey);
    String private = CryptoUtils.encodeRSAPrivateKeyToPem(
        keys.privateKey as rsa.RSAPrivateKey);
    if (await ClientKeyManager().doesContactExist(client.serverUrl, toUser)) {
      await ClientKeyManager().updateContact(client.serverUrl, toUser,
          publicKey: public, privateKey: private);
    } else {
      await ClientKeyManager().createContact(client.serverUrl, toUser,
          publicKey: public, privateKey: private);
    }

    Map toSend = {
      MagicNumber.PUBLIC_KEY_DELIM: public,
      MagicNumber.TO_USER: [toUser]
    };
    String str = jsonEncode(toSend);
    await sendMessage(str);
  }
}
