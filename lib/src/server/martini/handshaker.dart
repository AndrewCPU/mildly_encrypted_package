import 'dart:convert';
import 'dart:io';

import 'package:encrypt/encrypt.dart';

import '../../logging/ELog.dart';
import '../../utils/communication_level.dart';
import '../../utils/crypto_utils.dart';
import '../../utils/encryption_util.dart';
import '../../utils/json_validator.dart';
import '../../utils/magic_nums.dart';
import '../../utils/status_code.dart';
import '../data/key_handler.dart';
import '../data/user_handler.dart';
import '../user/user.dart';
import 'olive_data.dart';
import 'package:pointycastle/asymmetric/api.dart' as rsa;
import 'package:pointycastle/api.dart' as asym;

class HandShaker {
  static final HandShaker _instance = HandShaker._internal();
  factory HandShaker() {
    return _instance;
  }
  HandShaker._internal();

  final Map<WebSocket, String> _handshaking = {};
  final Map<String, AuthenticationData> _authData = {};
  final Map<String, asym.AsymmetricKeyPair> _keyPairCache = {};

  bool _isHandshaking(WebSocket socket) {
    return _handshaking.containsKey(socket);
  }

  void identifyUser(WebSocket socket, dynamic data) {
    if (_isHandshaking(socket)) {
      _handleHandshake(socket, data);
    } else {
      _handshakeClient(socket, data);
    }
  }

  String? _getUUID(WebSocket socket) {
    return _handshaking[socket];
  }

  Future<String?> _decrypt(WebSocket socket, List<String> messages) async {
    if (_keyPairCache.containsKey(_getUUID(socket))) {
      Encrypter encrypter = EncryptionUtil.createEncrypter(null, _keyPairCache[_getUUID(socket)!]!.privateKey as rsa.RSAPrivateKey);
      return EncryptionUtil.decryptParts(messages, encrypter);
    } else {
      User? user = await UserHandler().getOrLoadUser(_getUUID(socket)!);
      if (user == null) {
        socket.add(jsonEncode({MagicNumber.STATUS: StatusCode.SERVER_ERROR}));
        return null;
      } else {
        return user.decryptParts(messages);
      }
    }
  }

  void _handleCompiledMessage(WebSocket socket, dynamic data) async {
    if (!JSONValidate.isValidJSON(data)) {
      return;
    }
    List<String> messages = (jsonDecode(data)[MagicNumber.MESSAGE_COMPILATION] as List).cast<String>();
    String? decrypted = await _decrypt(socket, messages);
    if (decrypted == null) {
      ELog.e("Could not find user in database when attempting to decrypt.");
      socket.add(jsonEncode({MagicNumber.STATUS: StatusCode.SERVER_ERROR}));
      return;
    }
    _handleDecryptedMessage(socket, decrypted);
  }

  void _handleDecryptedMessage(WebSocket socket, String message) async {
    if (!JSONValidate.isValidJSON(message, requiredKeys: [MagicNumber.CODE_1_DELIM, MagicNumber.CODE_2_DELIM, MagicNumber.PUSH_NOTIFICATION_DELIM])) {
      ELog.e("User has not been identified yet provided $message");
      socket.add(jsonEncode({MagicNumber.STATUS: StatusCode.HANDSHAKE_TIME_OUT}));
      return;
    }
    Map<String, dynamic> dt = jsonDecode(message);
    int c = dt[MagicNumber.CODE_1_DELIM];
    int d = dt[MagicNumber.CODE_2_DELIM];
    String pushNotification = dt[MagicNumber.PUSH_NOTIFICATION_DELIM];
    if (_handshaking.containsKey(socket) && _authData.containsKey(_getUUID(socket))) {
      String uuid = _getUUID(socket)!;
      AuthenticationData authData = _authData[uuid]!;
      if (authData.codes[0] == c && authData.codes[1] == d) {
        if (authData.expiration > DateTime.now().millisecondsSinceEpoch) {
          User? user = await UserHandler().getOrLoadUser(uuid);
          if (user == null) {
            ELog.e("User successfully authenticated, but cannot be found in database $uuid");
            _handshaking.remove(socket);
            _keyPairCache.remove(_getUUID(socket));
            _authData.remove(_getUUID(socket));
            return;
          }
          if (_keyPairCache.containsKey(uuid)) {
            ELog.i("New User $uuid");
            await KeyHandler().updateUserKey(user, privateKey: CryptoUtils.encodeRSAPrivateKeyToPem(_keyPairCache[uuid]!.privateKey as rsa.RSAPrivateKey));
          }
          await user.identified(socket);
          await user.sendMessage(jsonEncode({MagicNumber.STATUS: StatusCode.SUCCESS}));
          await user.updatePushNotificationCode(pushNotification);
          _handshaking.remove(socket);
          _keyPairCache.remove(user.uuid);
          _authData.remove(user.uuid);
        } else {
          ELog.e("User tried to identify but response was slower than handshake expiration.  $uuid");
          socket.add(jsonEncode({MagicNumber.STATUS: StatusCode.HANDSHAKE_TIME_OUT}));
          _handshaking.remove(socket);
          _keyPairCache.remove(_getUUID(socket));
          _authData.remove(_getUUID(socket));
        }
      } else {
        ELog.e("User tried to identify but provided incorrect codes. $uuid");
        socket.add(jsonEncode({MagicNumber.STATUS: StatusCode.INVALID_DATA}));
        _handshaking.remove(socket);
        _keyPairCache.remove(_getUUID(socket));
        _authData.remove(_getUUID(socket));
      }
    } else {
      ELog.e("Handshake records cannot be found for user sign in. UUID unlocated.");
      socket.add(jsonEncode({MagicNumber.STATUS: StatusCode.HANDSHAKE_TIME_OUT}));
      _handshaking.remove(socket);
      _keyPairCache.remove(_getUUID(socket));
      _authData.remove(_getUUID(socket));
    }
  }

  // Handshake followup should always be encrypted, by this point we have paired the socket with a UUID
  // If it's a new user, they've been given our public key and the codes, if it's existing our
  // keys have already been exchanged. We should be able to fully communicate here.
  // ['m'] should be set containing >=1 encrypted pieces.
  void _handleHandshake(WebSocket socket, dynamic data) {
    if (!JSONValidate.isValidJSON(data, requiredKeys: [MagicNumber.MESSAGE_COMPILATION])) {
      ELog.e(data);
      ELog.e("Handshake response does not contain message compilation parts for ${_getUUID(socket)}");
      return;
    }
    _handleCompiledMessage(socket, data);
  }

  void _handshakeClient(WebSocket socket, dynamic data) async {
    if (!JSONValidate.isValidJSON(data, requiredKeys: [MagicNumber.USER_ID_DELIM])) {
      socket.add(jsonEncode({MagicNumber.STATUS: StatusCode.MISSING_DATA}));
      ELog.e("User has not been identified yet provided $data");
      return;
    }
    String? includePublicKey;
    Map json = jsonDecode(data);
    if (JSONValidate.isValidJSON(data, requiredKeys: [MagicNumber.PUBLIC_KEY_DELIM, MagicNumber.USER_ID_DELIM])) {
      // p = public_key, u = desired uuid
      User? user = await UserHandler().createUser(json[MagicNumber.USER_ID_DELIM], json[MagicNumber.PUBLIC_KEY_DELIM]);
      if (user == null) {
        socket.add(jsonEncode({MagicNumber.STATUS: StatusCode.FAILED_TO_CREATE_USER}));
        ELog.e("User account could not be created. createUser(${json[MagicNumber.USER_ID_DELIM]}, ${json[MagicNumber.PUBLIC_KEY_DELIM]}) failed.");
        return;
      } else {
        asym.AsymmetricKeyPair keys = CryptoUtils.generateRSAKeyPair();
        _keyPairCache[user.uuid] = keys;
        includePublicKey = CryptoUtils.encodeRSAPublicKeyToPem(keys.publicKey as rsa.RSAPublicKey);
      }
    }
    _handshaking[socket] = json[MagicNumber.USER_ID_DELIM];
    bool keep = false;
    if (_authData[json[MagicNumber.USER_ID_DELIM]] != null) {
      AuthenticationData data = _authData[json[MagicNumber.USER_ID_DELIM]]!;
      if (data.expiration > DateTime.now().millisecondsSinceEpoch) {
        keep = true;
      }
    }
    if (!keep) {
      _authData[json[MagicNumber.USER_ID_DELIM]] = AuthenticationData.generate();
    }
    _sendAuthData(socket, publicKey: includePublicKey);
  }

  void _sendAuthData(WebSocket socket, {String? publicKey}) async {
    User? user = UserHandler().getUser(uuid: _handshaking[socket]!);
    user ??= await UserHandler().loadUser(_handshaking[socket]!);
    if (user == null) {
      ELog.e("Trying to send auth data to a user who doesn't exist! User: ${_handshaking[socket]}");
      socket.add(jsonEncode({MagicNumber.STATUS: StatusCode.SERVER_ERROR}));
      return;
    }
    if ((user.communicationLevel == CommunicationLevel.canSend && _keyPairCache.containsKey(user.uuid)) || user.communicationLevel == CommunicationLevel.full) {
      Map sending = {MagicNumber.CODE_1_DELIM: _authData[user.uuid]!.codes[0], MagicNumber.CODE_2_DELIM: _authData[user.uuid]!.codes[1]};
      if (publicKey != null) {
        sending[MagicNumber.PUBLIC_KEY_DELIM] = publicKey;
      }
      List<String> encryptedPieces = await user.getEncryptedPieces(jsonEncode(sending));
      socket.add(jsonEncode({MagicNumber.MESSAGE_COMPILATION: encryptedPieces}));
      // socket.add(user.encrypt();
    }
  }
}
