import 'dart:async';
import 'dart:convert';

import 'package:mildly_encrypted_package/mildly_encrypted_package.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientManagement.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientUser.dart';
import 'package:mildly_encrypted_package/src/logging/ELog.dart';
import 'package:mildly_encrypted_package/src/sql_wrapper/db/SDatabase.dart';
import 'package:mildly_encrypted_package/src/sql_wrapper/sql_wrapper.dart';
import 'package:mildly_encrypted_package/src/utils/json_validator.dart';
import 'package:path/path.dart';

class MessageStorage {
  static final MessageStorage _instance = MessageStorage._internal();
  Timer? expirationTimer;
  MessageStorage._internal() {
    expirationTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      int now = DateTime.now().millisecondsSinceEpoch;
      Map<ClientUser, bool> needsRebuild = {};
      ClientManagement management = await ClientManagement.getInstance();
      List<ClientUser> everyone = management.getAllUsers();
      for (ClientUser user in everyone) {
        if (expirationTimes.containsKey(user)) {
          for (int time in expirationTimes[user]!) {
            if (time < now) {
              needsRebuild[user] = true;
            }
          }
        }
      }

      for (ClientUser user in needsRebuild.keys) {
        if (needsRebuild[user]!) {
          UpdateNotificationRegistry.getInstance().messageUpdate(user, '');
        }
      }
    });
  }

  SDatabase? database;

  factory MessageStorage() {
    return _instance;
  }

  Map<ClientUser, List<int>> expirationTimes = {};

  Future<void> init() async {
    database ??= await SQLFactory().openDatabase(
      join('./client_message_data.db'),
    );
    // await _createKeyLogs();
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

  String getTableName(String serverIP, String uuid) {
    return "$serverIP-$uuid";
  }

  Future<bool> doesChatTableExist(String serverIP, String uuid) async {
    await _initIfNot();
    //SELECT name FROM sqlite_master WHERE type='table' AND name='table_name';
    return (await database!.query('sqlite_master', where: 'type = ? AND name = ?', whereArgs: ['table', getTableName(serverIP, uuid)])).isNotEmpty;
  }

  Future<void> createChatTable(String serverIP, String uuid) async {
    await _initIfNot();
    await database!.createTable(getTableName(serverIP, uuid), [
      'message_uuid TEXT PRIMARY KEY', // string
      'sender_uuid TEXT', // string
      'message_content TEXT', // string
      'message_data TEXT', // json encoded map
      'message_time INTEGER', // time in ms
    ]);
  }

  Future<void> deleteChatTable(String serverIP, String chatID) async {
    await _initIfNot();
    await database!.deleteTable(getTableName(serverIP, chatID));
  }

  Future<void> deleteMessage(String serverIP, String chatID, String messageID) async {
    await _initIfNot();
    await database!.delete(getTableName(serverIP, chatID), where: 'message_uuid = ?', whereArgs: [messageID]);
  }

  Future<void> insertMessage(String serverIP, String uuid,
      {required String messageUuid, required String senderUuid, required String messageContent, required Map messageData, required int timeMs}) async {
    await _initIfNot();
    if (!(await doesChatTableExist(serverIP, uuid))) {
      ELog.e("Tried inserting a message even though the table doesn't exist. $serverIP & $uuid");
      return;
    }
    await database!.insert(getTableName(serverIP, uuid), {
      'message_uuid': messageUuid,
      'sender_uuid': senderUuid,
      'message_content': messageContent,
      'message_data': jsonEncode(messageData),
      'message_time': timeMs,
    });
  }

  Future<List<T>?> getMessages<T>(
      String serverIP,
      String chatID,
      T Function({required ClientUser? sender, required String messageUuid, required int time, required String messageContent, required Map data})
          builder) async {
    await _initIfNot();
    if (!(await doesChatTableExist(serverIP, chatID))) {
      ELog.e("Tried getting messages from a table that doesn't exist yet! $serverIP & $chatID");
      return null;
    }
    var results = await database!.query(getTableName(serverIP, chatID), orderBy: 'message_time ASC');
    List<T> response = [];
    List<String> messageUuidsDelete = [];
    ClientUser userObject = (await ((await ClientManagement.getInstance()).getFromUUID(chatID)))!;
    expirationTimes[userObject] = [];
    for (Map result in results) {
      if (JSONValidate.isValidJSON(result['message_data'], requiredKeys: ['expires'])) {
        int expiresTime = jsonDecode(result['message_data'])['expires'];
        if (DateTime.now().millisecondsSinceEpoch > expiresTime) {
          messageUuidsDelete.add(result['message_uuid']);
          continue;
        } else {
          expirationTimes[userObject] ??= [];
          expirationTimes[userObject]!.add(expiresTime);
        }
      }

      ClientUser? sender;
      if (result['sender_uuid'] == 'notification') {
        sender = null;
      } else {
        sender = ((await (await ClientManagement.getInstance()).getUser(result['sender_uuid'])));
      }
      response.add(builder(
          sender: sender,
          messageUuid: result['message_uuid'],
          time: result['message_time'],
          messageContent: result['message_content'],
          data: jsonDecode(result['message_data'])));
    }
    for (String messageUuid in messageUuidsDelete) {
      await deleteMessage(serverIP, chatID, messageUuid);
    }
    return response;
  }

  Future<int?> getLastMessageTime(String serverIP, String chatID) async {
    await _initIfNot();
    if (!(await doesChatTableExist(serverIP, chatID))) {
      ELog.e("Tried getting messages from a table that doesn't exist yet! $serverIP & $chatID");
      return null;
    }
    var results = await database!.query(getTableName(serverIP, chatID), orderBy: 'message_time DESC', limit: 1);
    if (results.isEmpty) {
      return 0;
    }
    return results[0]['message_time'];
  }

  Future<void> updateMessage(String serverIP, String chatID, String messageUuid, Map data) async {
    if (!(await doesChatTableExist(serverIP, chatID))) {
      ELog.e("Cannot update a message in a table that doesn't exist! $serverIP & $chatID");
      return;
    }
    if (!(await doesMessageIDExist(serverIP, chatID, messageUuid))) {
      ELog.e("Cannot update a message that doesn't exist! $serverIP & $chatID & $messageUuid");
    }
    await database!.update(getTableName(serverIP, chatID), {'message_data': jsonEncode(data)}, where: 'message_uuid = ?', whereArgs: [messageUuid]);
  }

  Future<bool> doesMessageIDExist(String serverIP, String chatID, String messageUuid) async {
    var response = await database!.query(getTableName(serverIP, chatID), where: 'message_uuid = ?', whereArgs: [messageUuid]);
    if (response.isEmpty) {
      ELog.e("Cannot get message that doesn't exist! $serverIP & $chatID & $messageUuid");
      return false;
    }
    return true;
  }

  Future<T?> getMessage<T>(String serverIP, String chatID, String messageUuid,
      T Function({required String sender, required String messageUuid, required int time, required String messageContent, required Map data}) builder) async {
    if (!(await doesChatTableExist(serverIP, chatID))) {
      ELog.e("Cannot get message from table that doesn't exist! $serverIP & $chatID");
      return null;
    }
    var response = await database!.query(getTableName(serverIP, chatID), where: 'message_uuid = ?', whereArgs: [messageUuid]);
    if (response.isEmpty) {
      ELog.e("Cannot get message that doesn't exist! $serverIP & $chatID & $messageUuid");
      return null;
    }
    var result = response[0];
    return builder(
        sender: result['sender_uuid'],
        messageUuid: result['message_uuid'],
        time: result['message_time'],
        messageContent: result['message_content'],
        data: jsonDecode(result['message_data']));
  }

  // void test() async {
  //   List<Message>? builtMessageObjects =
  //       await getMessages<Message>("127.0.0.1", "test", (
  //           {required String sender,
  //           required String messageUuid,
  //           required int time,
  //           required String messageContent,
  //           required Map data}) {
  //     return Message(
  //         sender: sender,
  //         messageUuid: messageUuid,
  //         time: time,
  //         messageContent: messageContent,
  //         data: data);
  //   });
  // }

  //what do i need from a message?
  // chatWithApple
  // messageUuid, sender uuid, message content, message meta data, time

}
