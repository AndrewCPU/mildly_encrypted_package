import 'dart:convert';

import 'package:encrypt/encrypt.dart';
import 'package:mildly_encrypted_package/mildly_encrypted_package.dart';
import 'package:mildly_encrypted_package/src/client/data/client_key_manager.dart';
import 'package:mildly_encrypted_package/src/utils/crypto_utils.dart';
import 'package:mildly_encrypted_package/src/utils/encryption_util.dart';
import 'package:mildly_encrypted_package/src/utils/magic_nums.dart';

import 'ServerObject.dart';

import 'package:pointycastle/asymmetric/api.dart' as rsa;
import 'package:pointycastle/api.dart' as asym;

class EncryptedKeyExchanger {
  static Future<void> exchangeKey(String uuid, String remoteKeyPublicKey) async {
    EncryptedClient client = EncryptedClient.getInstance()!;

    String public;
    String private;

    if (await ClientKeyManager().doesContactExist(client.serverUrl, uuid)) {
      if (await ClientKeyManager().getColumnData(client.serverUrl, uuid, 'public_key') != '') {
        public = await ClientKeyManager().getColumnData(client.serverUrl, uuid, 'public_key');
        private = await ClientKeyManager().getColumnData(client.serverUrl, uuid, 'private_key');
      } else {
        asym.AsymmetricKeyPair keys = CryptoUtils.generateRSAKeyPair();
        public = CryptoUtils.encodeRSAPublicKeyToPem(keys.publicKey as rsa.RSAPublicKey);
        private = CryptoUtils.encodeRSAPrivateKeyToPem(keys.privateKey as rsa.RSAPrivateKey);
        await ClientKeyManager().updateContact(client.serverUrl, uuid, publicKey: public, privateKey: private);
      }
    } else {
      asym.AsymmetricKeyPair keys = CryptoUtils.generateRSAKeyPair();
      public = CryptoUtils.encodeRSAPublicKeyToPem(keys.publicKey as rsa.RSAPublicKey);
      private = CryptoUtils.encodeRSAPrivateKeyToPem(keys.privateKey as rsa.RSAPrivateKey);
      await ClientKeyManager().createContact(client.serverUrl, uuid, publicKey: public, privateKey: private);
    }

    Map bits = {
      MagicNumber.ENCRYPTED_KEY_EXCHANGE: public,
    };

    String message = jsonEncode(bits);

    Encrypter encrypter = Encrypter(RSA(publicKey: CryptoUtils.rsaPublicKeyFromPem(remoteKeyPublicKey)));

    List<String> encryptedBlocks = await EncryptionUtil.toEncryptedPieces(message, encrypter);
    Map send = {
      MagicNumber.ENCRYPTED_KEY_EXCHANGE: encryptedBlocks,
      MagicNumber.TO_USER: [uuid]
    }; // user encrypted data
    String toSendJson = jsonEncode(send);
    //check that we are authenticated before trying to send data packet. if we're not queue the message and wait for reconnect to go through
    if (!EncryptedClient.getInstance()!.isConnected() || !EncryptedClient.getInstance()!.isAuthenticated()) {
      client.offlineQueue.add(toSendJson);
      await client.reconnect();
    } else {
      ServerObject obj = await client.getServerObject();
      await obj.sendMessage(toSendJson);
    }
  }
}
