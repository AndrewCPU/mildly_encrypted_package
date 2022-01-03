import 'dart:convert';

import 'package:mildly_encrypted_package/src/client/data/message_storage.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/message_handler.dart';
import 'package:mildly_encrypted_package/src/logging/ELog.dart';
import 'package:path/path.dart';
// import 'package:sqflite/sqflite.dart';

import '../../sql_wrapper/db/SDatabase.dart';
import '../../sql_wrapper/sql_wrapper.dart';
import '../../utils/crypto_utils.dart';
import '../../utils/encryption_util.dart';
import '../../utils/key_type.dart';
import 'package:pointycastle/asymmetric/api.dart' as rsa;
import 'package:pointycastle/api.dart' as asym;

class ClientKeyManager {
  static final ClientKeyManager _instance = ClientKeyManager._internal();
  SDatabase? database;

  factory ClientKeyManager() {
    return _instance;
  }
  ClientKeyManager._internal();

  final String _mainTableName = "key_logs";

  Future<void> _createKeyLogs() async {
    await database!.createTable(_mainTableName, [
      'id INTEGER PRIMARY KEY AUTOINCREMENT',
      'server_ip TEXT',
      'uuid TEXT',
      'public_key TEXT',
      'private_key TEXT',
      'remote_public_key TEXT',
      'rand_key INTEGER',
      'remote_rand_key INTEGER',
      'data TEXT'
    ]);
    // (await database!.rawQuery(
    //     'CREATE TABLE IF NOT EXISTS `$_mainTableName` (id INTEGER PRIMARY KEY AUTOINCREMENT, server_ip TEXT, uuid TEXT, public_key TEXT, private_key TEXT, remote_public_key TEXT, rand_key INTEGER, remote_rand_key INTEGER, data TEXT);'));
    return;
  }

  Future<void> init() async {
    database ??= await SQLFactory().openDatabase(
      join('./client_key_data.db'),
    );
    await _createKeyLogs();
    return;
  }

  bool _isInitialized() {
    return database != null && database!.isOpen();
  }

  Future<void> _initIfNot() async {
    if (!_isInitialized()) {
      await init();
    }
  }

  Future<bool> doesContactExist(String serverIP, String uuid) async {
    await _initIfNot();
    var result = await database!.query(_mainTableName, where: 'server_ip = ? AND uuid = ?', whereArgs: [serverIP, uuid], limit: 1);
    return result.isNotEmpty;
  }

  Future<Map<String, List<String>>> getAllContactUUIDs(String serverIP) async {
    List<Map> contacts = await database!.query(_mainTableName, where: 'server_ip = ?', whereArgs: [serverIP]);
    List<String> users = [];
    List<String> groups = [];
    for (Map m in contacts) {
      if (jsonDecode(m['data']).containsKey('members')) {
        groups.add(m['uuid']);
      } else {
        users.add(m['uuid']);
      }
    }
    users.remove('server');
    groups.remove('server');
    return {'groups': groups, 'users': users};
  }

  Future<bool> isGroupChat(String serverIP, String chatID) async {
    Map? data = await getUserData(serverIP, chatID);
    if (data == null) {
      return false;
    }
    return (data.containsKey('members'));
  }

  Future<void> deleteContact(String serverIP, String chatID) async {
    await _initIfNot();
    await database!.delete(_mainTableName, where: 'uuid = ?', whereArgs: [chatID]);
    await MessageStorage().deleteChatTable(serverIP, chatID);
  }

  Future<void> createContact(String serverIP, String uuid,
      {String? publicKey, String? privateKey, String? remotePublic, int? randInt, int? remoteRandInt, Map? data}) async {
    await _initIfNot();
    await database!.insert(_mainTableName, {
      'id': null,
      'server_ip': serverIP,
      'uuid': uuid,
      'public_key': publicKey ?? '',
      'private_key': privateKey ?? '',
      'remote_public_key': remotePublic ?? '',
      'rand_key': randInt ?? -1,
      'remote_rand_key': remoteRandInt ?? -1,
      'data': jsonEncode(data ?? {})
    });
    await MessageStorage().createChatTable(serverIP, uuid);
  }

  Future<void> updateContact(String serverIP, String uuid,
      {String? publicKey, String? privateKey, String? remotePublic, int? randInt, int? remoteRandInt, Map? data}) async {
    await _initIfNot();
    Map<String, dynamic> rebuild = {};
    rebuild['public_key'] = publicKey;
    rebuild['private_key'] = privateKey;
    rebuild['remote_public_key'] = remotePublic;
    rebuild['rand_key'] = randInt;
    rebuild['remote_rand_key'] = remoteRandInt;
    rebuild['data'] = data == null ? data : jsonEncode(data);
    rebuild.removeWhere((key, value) => value == null);
    await database!.update(_mainTableName, rebuild, where: 'server_ip = ? AND uuid = ?', whereArgs: [serverIP, uuid]);
  }

  Future<Map<String, Object?>> getUserRow(String serverIP, String uuid) async {
    await _initIfNot();
    var result = await database!.query(_mainTableName, where: 'server_ip = ? AND uuid = ?', whereArgs: [serverIP, uuid], limit: 1);
    return result[0].cast<String, Object?>();
  }

  Future<String> getColumnData(String serverIP, String uuid, String column) async {
    return (await getUserRow(serverIP, uuid))[column].toString();
  }

  Future<bool> hasValidPrivateKey(String serverIP, String uuid) async {
    await _initIfNot();
    if (!(await doesContactExist(serverIP, uuid))) {
      return false;
    }
    String privateKey = await getColumnData(serverIP, uuid, 'private_key');
    return EncryptionUtil.isKeyValid(KeyType.private, privateKey);
  }

  Future<bool> hasValidPublicKey(String serverIP, String uuid) async {
    await _initIfNot();
    if (!(await doesContactExist(serverIP, uuid))) {
      return false;
    }
    String publicKey = await getColumnData(serverIP, uuid, 'public_key');
    return EncryptionUtil.isKeyValid(KeyType.public, publicKey);
  }

  Future<bool> hasValidRemotePublicKey(String serverIP, String uuid) async {
    await _initIfNot();
    if (!(await doesContactExist(serverIP, uuid))) {
      return false;
    }
    String remotePublicKey = await getColumnData(serverIP, uuid, 'remote_public_key');
    return EncryptionUtil.isKeyValid(KeyType.public, remotePublicKey);
  }

  Future<rsa.RSAPublicKey?> getRSAPublicKey(String serverIP, String uuid) async {
    if (!await hasValidPublicKey(serverIP, uuid)) {
      return null;
    }
    String publicKey = await getColumnData(serverIP, uuid, 'public_key');
    return CryptoUtils.rsaPublicKeyFromPem(publicKey);
  }

  Future<rsa.RSAPublicKey?> getRSARemotePublicKey(String serverIP, String uuid) async {
    if (!await hasValidRemotePublicKey(serverIP, uuid)) {
      return null;
    }
    String publicKey = await getColumnData(serverIP, uuid, 'remote_public_key');
    return CryptoUtils.rsaPublicKeyFromPem(publicKey);
  }

  Future<rsa.RSAPrivateKey?> getRSAPrivateKey(String serverIP, String uuid) async {
    if (!await hasValidPrivateKey(serverIP, uuid)) {
      return null;
    }
    String privateKey = await getColumnData(serverIP, uuid, 'private_key');
    return CryptoUtils.rsaPrivateKeyFromPem(privateKey);
  }

  Future<Map?> getUserData(String serverIP, String uuid) async {
    if (!await doesContactExist(serverIP, uuid)) {
      return null;
    }
    Map row = jsonDecode(await getColumnData(serverIP, uuid, 'data'))!;
    return row;
  }

  Future<bool> hasAllValidKeys(String serverIP, String uuid) async {
    return await haveWeSentKeys(serverIP, uuid) && await haveWeReceivedKeys(serverIP, uuid);
  }

  Future<bool> haveWeSentKeys(String serverIP, String uuid) async {
    return await hasValidPrivateKey(serverIP, uuid) && await hasValidPublicKey(serverIP, uuid);
  }

  Future<bool> haveWeReceivedKeys(String serverIP, String uuid) async {
    return await hasValidRemotePublicKey(serverIP, uuid);
  }

  Future<bool> haveWeSentRandInt(String serverIP, String uuid) async {
    return await getColumnData(serverIP, uuid, 'rand_key') != '-1';
  }

  Future<bool> haveWeReceivedRandInt(String serverIP, String uuid) async {
    return await getColumnData(serverIP, uuid, 'remote_rand_key') != '-1';
  }

  Future<bool> isRandIntDone(String serverIP, String uuid) async {
    return await haveWeSentRandInt(serverIP, uuid) && await haveWeReceivedRandInt(serverIP, uuid);
  }

  Future<List<int>?> getGroupChatSeeds(String serverIP, String chatID) async {
    Map? data = await getUserData(serverIP, chatID);
    if (data == null) {
      ELog.e("Cannot get seeds from a chat that doesn't exist!");
      return null;
    }
    if (!data.containsKey('seeds')) {
      ELog.e("Cannot get seeds from user, they are not in key data.");
      return null;
    }
    return ((data['seeds'] as List).cast<int>());
  }

  Future<void> updateGroupSeeds(String serverIP, String chatID, List<int> seeds) async {
    Map? data = await getUserData(serverIP, chatID);
    if (data == null) {
      ELog.e("Cannot get seeds from a chat that doesn't exist!");
      return;
    }
    data['seeds'] = seeds;
    await updateContact(serverIP, chatID, data: data);
  }

  Future<void> generateNextKeySet(String serverIP, String groupID, int timeLeft) async {
    var dt = timeLeft;
    print("@ $dt");
    List<int>? seeds = await getGroupChatSeeds(serverIP, groupID);
    if (seeds == null) {
      ELog.e("Something went wrong while trying to iterate the group key. Seeds cannot be found!");
      return;
    }
    seeds[seeds.length - 1] = dt % 255;
    seeds[seeds.length - 2] = 255 - (dt % 255);
    asym.AsymmetricKeyPair keys3 = CryptoUtils.generateRSAKeyPair(seeds: seeds);
    String publicKey = (CryptoUtils.encodeRSAPublicKeyToPem(keys3.publicKey as rsa.RSAPublicKey));
    String privateKey = (CryptoUtils.encodeRSAPrivateKeyToPem(keys3.privateKey as rsa.RSAPrivateKey));
    await updateGroupSeeds(serverIP, groupID, seeds);
    await updateContact(serverIP, groupID,
        publicKey: publicKey, privateKey: privateKey, remotePublic: publicKey, randInt: privateKey.hashCode, remoteRandInt: publicKey.hashCode);
  }

  Future<List<String>?> getGroupChatMembers(String serverIP, String groupID) async {
    Map? data = await getUserData(serverIP, groupID);
    if (data == null) {
      ELog.e("Cannot get members from a chat that doesn't exist!");
      return null;
    }
    if (!data.containsKey('seeds')) {
      ELog.e("Cannot get members from user, they are not in key data.");
      return null;
    }
    return ((data['members'] as List).cast<String>());
  }

  Future<void> setGroupChatMembers(String serverIP, String groupID, List<String> members) async {
    Map? data = await getUserData(serverIP, groupID);
    if (data == null) {
      ELog.e("Cannot set members for a chat that doesn't exist!");
      return;
    }
    data['members'] = members;
    await updateContact(serverIP, groupID, data: data);
  }

  Future<void> removeUserFromGroupChat(String serverIP, String groupID, String whoIsLeaving, int timeLeft) async {
    await generateNextKeySet(serverIP, groupID, timeLeft);
    List<String>? members = await getGroupChatMembers(serverIP, groupID);
    if (members == null) {
      return;
    }
    members.remove(whoIsLeaving);
    await setGroupChatMembers(serverIP, groupID, members);
  }

  Future<void> reset() async {
    await _initIfNot();
    await database!.reset();
    database = null;
    await _initIfNot();
  }
}
