import 'dart:convert';

import 'package:encrypt/encrypt.dart';
import 'package:flutter/widgets.dart';

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
    remoteKey = await ClientKeyManager().getRSARemotePublicKey(client.serverUrl, uuid);
    privateKey = await ClientKeyManager().getRSAPrivateKey(client.serverUrl, uuid);
    _createEncrypter();
  }

  Future<void> refreshKeys() async {
    await _init();
  }

  Future<void> sendMessage(String message) async {
    List<String> encryptedBlock = await EncryptionUtil.toEncryptedPieces(message, encrypter);
    Map m = {MagicNumber.MESSAGE_COMPILATION: encryptedBlock};
    String messageJSON = jsonEncode(m);
    client.getChannel()!.sink.add(messageJSON);
  }

  Future<void> updateOnlineStatus(List<String> targetUUID) async {
    await sendMessage(jsonEncode({MagicNumber.ONLINE: targetUUID}));
  }

  Future<void> _exchangeKeys(String toUser, String keyPublicKey) async {
    String public;
    String private;
    if (await ClientKeyManager().doesContactExist(client.serverUrl, toUser)) {
      if (await ClientKeyManager().getColumnData(client.serverUrl, toUser, 'public_key') != '') {
        public = await ClientKeyManager().getColumnData(client.serverUrl, toUser, 'public_key');
        private = await ClientKeyManager().getColumnData(client.serverUrl, toUser, 'private_key');
      } else {
        asym.AsymmetricKeyPair keys = CryptoUtils.generateRSAKeyPair();
        public = CryptoUtils.encodeRSAPublicKeyToPem(keys.publicKey as rsa.RSAPublicKey);
        private = CryptoUtils.encodeRSAPrivateKeyToPem(keys.privateKey as rsa.RSAPrivateKey);
        await ClientKeyManager().updateContact(client.serverUrl, toUser, publicKey: public, privateKey: private);
      }
    } else {
      asym.AsymmetricKeyPair keys = CryptoUtils.generateRSAKeyPair();
      public = CryptoUtils.encodeRSAPublicKeyToPem(keys.publicKey as rsa.RSAPublicKey);
      private = CryptoUtils.encodeRSAPrivateKeyToPem(keys.privateKey as rsa.RSAPrivateKey);
      await ClientKeyManager().createContact(client.serverUrl, toUser, publicKey: public, privateKey: private);
    }

    Map toSend = {
      MagicNumber.PUBLIC_KEY_DELIM: public,
      MagicNumber.TO_USER: [toUser]
    };
    String str = jsonEncode(toSend);
    await sendMessage(str);
  }
}
