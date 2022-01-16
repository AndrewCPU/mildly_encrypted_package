import 'dart:convert';

import 'package:path/path.dart';
//
import '../../logging/ELog.dart';
import '../../sql_wrapper/db/SDatabase.dart';
import '../../sql_wrapper/sql_wrapper.dart';
import '../../utils/crypto_utils.dart';
import '../../utils/encryption_util.dart';
import '../../utils/key_type.dart';
import '../user/user.dart';
import 'package:pointycastle/asymmetric/api.dart' as rsa;
import 'package:pointycastle/api.dart' as asym;

class KeyHandler {
  static final KeyHandler _instance = KeyHandler._internal();
  KeyHandler._internal();

  SDatabase? database;

  factory KeyHandler() {
    return _instance;
  }

  String _mainTableName = 'key_logs';

  Future<void> _createKeyLog() async {
//`uuid` VARCHAR(64) NOT NULL PRIMARY KEY);'
    await database!.createTable(_mainTableName, ['uuid TEXT PRIMARY KEY', 'public_key TEXT', 'private_key TEXT', 'data TEXT']);
    // (await database!.rawQuery(
    //     'CREATE TABLE IF NOT EXISTS `$_mainTableName` (uuid TEXT PRIMARY KEY, public_key TEXT, private_key TEXT, data TEXT);'));
    return;
  }

  Future<void> init() async {
    database ??= await SQLFactory().openDatabase(
      join('/root/key_database/', 'key_data.db'),
    );
    await _createKeyLog();
    return;
  }

  void _databaseMod() {}
  //key_logs: uuid, public_key, private_key, data

  Future<bool> insertUser(String userID, String publicKey) async {
    if (!EncryptionUtil.isKeyValid(KeyType.public, publicKey)) {
      return false;
    }
    await database?.insert(_mainTableName, {'uuid': userID, 'public_key': publicKey, 'private_key': '', 'data': jsonEncode({})});
    _databaseMod();
    return true;
  }

  Future<String?> getUserDataColumn(String uuid) async {
    Map<String, Object?>? ud = await getUserData(uuid);
    if (ud == null) {
      return null;
    }
    return ud['data']!.toString();
  }

  Future<int?> updateUserDataColumn(String uuid, {String? dataString, Map? data}) async {
    if (data != null) {
      dataString = jsonEncode(data);
    }
    return await database?.update(_mainTableName, {'data': dataString}, where: 'uuid = ?', whereArgs: [uuid]);
  }

  Future<Map<String, Object?>?> getUserData(String uuid) async {
    var result = await database?.query(_mainTableName, where: 'uuid = ?', whereArgs: [uuid]);
    if (result == null || result.isEmpty) {
      return null;
    }
    return result[0].cast<String, Object?>();
  }

  Future<bool> doesUserExist(String uuid) async {
    var result = await getUserData(uuid);
    return result != null;
  }

  Future<String?> getPEMPublicKey(String uuid) async {
    if (!(await doesUserExist(uuid))) {
      return null;
    }
    Map<String, Object?> data = (await getUserData(uuid))!;
    return data['public_key'] as String;
  }

  Future<String?> getPEMPrivateKey(String uuid) async {
    if (!(await doesUserExist(uuid))) {
      return null;
    }
    Map<String, Object?> data = (await getUserData(uuid))!;
    return data['private_key'] as String;
  }

  Future<rsa.RSAPublicKey?> getRSAPublicKey(String uuid) async {
    String? pemPublic = await getPEMPublicKey(uuid);
    if (pemPublic == null) {
      return null;
    }
    return CryptoUtils.rsaPublicKeyFromPem(pemPublic);
  }

  Future<rsa.RSAPrivateKey?> getRSAPrivateKey(String uuid) async {
    String? pemPrivate = await getPEMPrivateKey(uuid);
    if (pemPrivate == null) {
      return null;
    }
    return CryptoUtils.rsaPrivateKeyFromPem(pemPrivate);
  }

  Future<void> updateUserKey(User user, {String? publicKey, String? privateKey}) async {
    Map<String, String> updateMap = {};
    if (publicKey != null) {
      if (EncryptionUtil.isKeyValid(KeyType.public, publicKey)) {
        user.update(KeyType.public, CryptoUtils.rsaPublicKeyFromPem(publicKey));
        updateMap['public_key'] = publicKey;
      } else {
        ELog.e("Provided public key for ${user.uuid} is invalid.");
      }
    }
    if (privateKey != null) {
      if (EncryptionUtil.isKeyValid(KeyType.private, privateKey)) {
        user.update(KeyType.private, CryptoUtils.rsaPrivateKeyFromPem(privateKey));
        updateMap['private_key'] = privateKey;
      } else {
        ELog.e("Provided private key for ${user.uuid} is invalid.");
      }
    }
    if (updateMap.keys.isEmpty) {
      ELog.i("There was an attempted key update with blank keys! User: ${user.uuid}");
      return;
    }
    await database?.update(_mainTableName, updateMap, where: 'uuid = ?', whereArgs: [user.uuid]);
    _databaseMod();
  }

  Future<bool> hasValidPublicKey(String uuid) async {
    String? s = await getPEMPublicKey(uuid);
    if (s == null) {
      return false;
    }
    return EncryptionUtil.isKeyValid(KeyType.public, s);
  }

  Future<bool> hasValidPrivateKey(String uuid) async {
    String? s = await getPEMPrivateKey(uuid);
    if (s == null) {
      return false;
    }
    return EncryptionUtil.isKeyValid(KeyType.private, s);
  }
}
