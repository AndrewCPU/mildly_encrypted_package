import 'dart:async';
import 'dart:convert';

import 'package:encrypt/encrypt.dart';
import 'package:mildly_encrypted_package/src/client/objs/ServerObject.dart';
import 'package:mildly_encrypted_package/src/utils/GetPath.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/io.dart';

import 'package:pointycastle/asymmetric/api.dart' as rsa;
import 'package:pointycastle/api.dart' as asym;

import '../../logging/ELog.dart';
import '../../utils/crypto_utils.dart';
import '../../utils/encryption_util.dart';
import '../../utils/json_validator.dart';
import '../../utils/key_type.dart';
import '../../utils/magic_nums.dart';
import '../../utils/save_file.dart';
import '../../utils/status_code.dart';
import '../client.dart';
import '../data/client_key_manager.dart';

class HandshakeHandler {
  static final HandshakeHandler _instance = HandshakeHandler._internal();

  HandshakeHandler._internal();

  factory HandshakeHandler() {
    return HandshakeHandler._instance;
  }

  void handleHandshake(IOWebSocketChannel channel, EncryptedClient client, {dynamic data}) async {
    SaveFile _save = await SaveFile.getInstance(path: GetPath.getInstance().path + "/data.json");
    if (data == null) {
      if (!_save.containsKey("uuid")) {
        await _createAccount(client.serverUrl);
      }
      client.uuid = await _save.getString('uuid');
      await _introduce(channel, client);
    } else {
      _handleResponse(channel, client, data);
    }
  }

  Future<void> _introduce(IOWebSocketChannel channel, EncryptedClient client) async {
    SaveFile _save = await SaveFile.getInstance(path: GetPath.getInstance().path + "/data.json");
    Map<String, String> intro = {};
    intro[MagicNumber.USER_ID_DELIM] = (await _save.getString("uuid"))!;
    if (!await ClientKeyManager().hasValidRemotePublicKey(client.serverUrl, 'server')) {
      intro[MagicNumber.PUBLIC_KEY_DELIM] = await ClientKeyManager().getColumnData(client.serverUrl, 'server', 'public_key');
    }
    channel.sink.add(jsonEncode(intro));
  }

  void _handleResponse(IOWebSocketChannel channel, EncryptedClient client, dynamic data) async {
    if (JSONValidate.isValidJSON(data, requiredKeys: [MagicNumber.STATUS])) {
      await _handleStatus(channel, client, data);
      return;
    }
    if (!JSONValidate.isValidJSON(data, requiredKeys: [MagicNumber.MESSAGE_COMPILATION])) {
      ELog.e("Server responded with invalid data during handshake! $data");
      return;
    }
    List<String> messageComp = (jsonDecode(data)[MagicNumber.MESSAGE_COMPILATION] as List).cast<String>();

    String ourPrivate = await ClientKeyManager().getColumnData(client.serverUrl, 'server', 'private_key');

    String message = EncryptionUtil.decryptParts(messageComp, EncryptionUtil.createEncrypter(null, CryptoUtils.rsaPrivateKeyFromPem(ourPrivate)));

    if (JSONValidate.isValidJSON(message, requiredKeys: [MagicNumber.STATUS])) {
      await _handleStatus(channel, client, message);
    } else if (JSONValidate.isValidJSON(message, requiredKeys: [MagicNumber.CODE_1_DELIM, MagicNumber.CODE_2_DELIM])) {
      await _authenticate(channel, client, message);
    } else {
      ELog.e("Server responses with invalid handshake response $message");
      return;
    }
  }

  Future<void> _handleStatus(IOWebSocketChannel channel, EncryptedClient client, String message) async {
    Map map = jsonDecode(message);
    int statusCode = map[MagicNumber.STATUS];
    if (statusCode == StatusCode.SUCCESS) {
      ELog.i("Successfully identified with server.");
      client.finishedAuthentication();
      ServerObject object = await ServerObject.getInstance(client);
      Timer(Duration(seconds: 2), () {
        object.sendMessage(jsonEncode({MagicNumber.ACTIVE: 'yes'}));
      });
      return;
    } else if (statusCode == StatusCode.FAILED_TO_CREATE_USER) {
      ELog.e("Invalid user ID.");
      await _createAccount(client.serverUrl); // recreate new UUID & keys
      await _introduce(channel, client); // introduce again
      return;
    } else if (statusCode == StatusCode.HANDSHAKE_TIME_OUT) {
      ELog.e("Handshake timed out.");
      await _introduce(channel, client);
      return;
    } else if (statusCode == StatusCode.INVALID_DATA) {
      ELog.e("Handshake had invalid data.");
      await _introduce(channel, client);
      return;
    } else if (statusCode == StatusCode.MISSING_DATA) {
      ELog.e("Handshake had missing data.");
      await _introduce(channel, client);
      return;
    } else if (statusCode == StatusCode.SERVER_ERROR) {
      ELog.e("Handshake went horribly wrong.");
      await _introduce(channel, client);
      return;
    }
  }

  Future<void> _createAccount(String serverIP) async {
    SaveFile _save = await SaveFile.getInstance(path: GetPath.getInstance().path + "/data.json");
    await _save.setString('uuid', Uuid().v4());
    var keyPair = CryptoUtils.generateRSAKeyPair();
    if (await ClientKeyManager().doesContactExist(serverIP, 'server')) {
      await ClientKeyManager().updateContact(serverIP, 'server',
          publicKey: CryptoUtils.encodeRSAPublicKeyToPem(keyPair.publicKey as rsa.RSAPublicKey),
          privateKey: CryptoUtils.encodeRSAPrivateKeyToPem(keyPair.privateKey as rsa.RSAPrivateKey));
    } else {
      await ClientKeyManager().createContact(serverIP, 'server',
          publicKey: CryptoUtils.encodeRSAPublicKeyToPem(keyPair.publicKey as rsa.RSAPublicKey),
          privateKey: CryptoUtils.encodeRSAPrivateKeyToPem(keyPair.privateKey as rsa.RSAPrivateKey));
    }
  }

  Future<void> _authenticate(IOWebSocketChannel channel, EncryptedClient client, String message) async {
    if (!JSONValidate.isValidJSON(message, requiredKeys: [MagicNumber.CODE_1_DELIM, MagicNumber.CODE_2_DELIM])) {
      ELog.e("Server responded with invalid data during handshake! $message");
      return;
    }
    Map jsonMessage = jsonDecode(message);
    String serverPublicKey;
    if (jsonMessage.containsKey(MagicNumber.PUBLIC_KEY_DELIM)) {
      serverPublicKey = jsonMessage[MagicNumber.PUBLIC_KEY_DELIM];
      await ClientKeyManager().updateContact(client.serverUrl, 'server', remotePublic: serverPublicKey);
    } else {
      serverPublicKey = await ClientKeyManager().getColumnData(client.serverUrl, 'server', 'remote_public_key');
    }
    if (!EncryptionUtil.isKeyValid(KeyType.public, serverPublicKey)) {
      ELog.e("Server public key is invalid. :( $serverPublicKey");
      return;
    }
    String ourPrivate = await ClientKeyManager().getColumnData(client.serverUrl, 'server', 'private_key');
    rsa.RSAPublicKey serverRSA = CryptoUtils.rsaPublicKeyFromPem(serverPublicKey);
    rsa.RSAPrivateKey privateRSA = CryptoUtils.rsaPrivateKeyFromPem(ourPrivate);
    Encrypter encrypter = EncryptionUtil.createEncrypter(serverRSA, privateRSA);
    int codeA = jsonMessage[MagicNumber.CODE_1_DELIM];
    int codeB = jsonMessage[MagicNumber.CODE_2_DELIM];
    Map response = {MagicNumber.CODE_1_DELIM: codeA, MagicNumber.CODE_2_DELIM: codeB, MagicNumber.PUSH_NOTIFICATION_DELIM: client.pushToken};
    String responseJson = jsonEncode(response);
    List<String> responseParts = EncryptionUtil.toEncryptedPieces(responseJson, encrypter);
    channel.sink.add(jsonEncode({MagicNumber.MESSAGE_COMPILATION: responseParts}));
  }
}
