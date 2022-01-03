import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:encrypt/encrypt.dart';
import 'package:mildly_encrypted_package/src/client/cutil/client_components.dart';
import 'package:mildly_encrypted_package/src/client/cutil/notification_registry.dart';
import 'package:mildly_encrypted_package/src/client/data/message_storage.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/subs/usermsgevents/chat_events/reaction_handler.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/subs/usermsgevents/chat_events/read_status_handler.dart';
import 'package:mildly_encrypted_package/src/client/objs/encryption_pack.dart';
import 'package:mildly_encrypted_package/src/client/objs/message_update_builder.dart';
import 'package:mildly_encrypted_package/src/utils/GetPath.dart';
import 'package:mildly_encrypted_package/src/utils/aes/file_download.dart';
import 'package:uuid/uuid.dart';

import '../../logging/ELog.dart';
import '../../utils/encryption_util.dart';
import '../../utils/magic_nums.dart';
import '../client.dart';
import '../data/client_key_manager.dart';
import 'package:pointycastle/asymmetric/api.dart' as rsa;
import 'package:pointycastle/api.dart' as asym;

import 'ServerObject.dart';

class ClientUser {
  static Future<ClientUser?> loadUser(EncryptedClient client, String uuid) async {
    ClientKeyManager keyManager = ClientKeyManager();
    if (!(await keyManager.doesContactExist(client.serverUrl, uuid))) {
      ELog.e("Client does not exist. Cannot be loaded ($uuid)");
      return null;
    }
    ClientUser user = ClientUser.internal(uuid, client);
    await user.init();
    return user;
  }

  String uuid;
  EncryptedClient client;
  ClientUser.internal(this.uuid, this.client);

  late String username;
  late String profilePicturePath;

  late rsa.RSAPrivateKey? privateKey;
  late rsa.RSAPublicKey? remoteKey;
  late Encrypter encrypter;

  void _createEncrypter() {
    encrypter = EncryptionUtil.createEncrypter(remoteKey, privateKey);
  }

  Future<String> sendChatMessage(String messageContent, {Map? specialData, Map? localDifference}) async {
    String messageUuid = Uuid().v4();
    Map data = {ClientComponent.TIME: DateTime.now().millisecondsSinceEpoch, ClientComponent.MESSAGE_UUID: messageUuid};
    if (specialData != null) {
      data.addAll(specialData);
    }

    Map messageMap = {ClientComponent.MESSAGE_CONTENT: messageContent, ClientComponent.MESSAGE_METADATA: data};
    Map? localSpecial;
    if (specialData != null) {
      localSpecial = Map.from(specialData);
      if (localDifference != null) {
        localSpecial.addAll(localDifference);
      }
    }
    await MessageStorage().insertMessage(client.serverUrl, uuid,
        messageUuid: messageUuid,
        senderUuid: client.uuid!,
        messageContent: messageContent,
        messageData: localSpecial ?? {},
        timeMs: data[ClientComponent.TIME]);
    await sendDataPacket(jsonEncode(messageMap));
    UpdateNotificationRegistry.getInstance().newMessage(this, messageUuid);
    return messageUuid;
  }

  Future<void> sendDataPacket(String message) async {
    List<String> encryptedBlocks = EncryptionUtil.toEncryptedPieces(message, encrypter);
    Map send = {
      MagicNumber.MESSAGE_COMPILATION: encryptedBlocks,
      MagicNumber.TO_USER: [uuid]
    }; // user encrypted data
    String toSendJson = jsonEncode(send);
    ServerObject obj = await ServerObject.getInstance(client);
    await obj.sendMessage(toSendJson);
  }

  Future<int> getRandInt() async {
    return int.parse(await ClientKeyManager().getColumnData(client.serverUrl, uuid, 'rand_key'));
  }

  Future<int> getRemoteRandInt() async {
    return int.parse(await ClientKeyManager().getColumnData(client.serverUrl, uuid, 'remote_rand_key'));
  }

  String decryptFromUser(List<String> messageParts) {
    return EncryptionUtil.decryptParts(messageParts, encrypter);
  }

  Future<void> sendFile(String path) async {
    Directory directory = Directory(GetPath.getInstance().path + Platform.pathSeparator + uuid + Platform.pathSeparator);
    String encryptFile = await EncryptionUtil.encryptFileToPath(path, this, directory.path);
    String? uploadedPath = await FileDownload.uploadFile(encryptFile);
    if (uploadedPath == null) {
      ELog.e("Something went wrong with a file upload! to $uuid");
      return;
    }
    String newLocalCopy = directory.path + Platform.pathSeparator + path.substring(path.lastIndexOf(Platform.pathSeparator) + 1);
    await File(path).copy(newLocalCopy);
    await sendChatMessage('', specialData: {ClientComponent.FILE_URL: uploadedPath}, localDifference: {ClientComponent.FILE_URL: newLocalCopy});
  }

  Future<void> reactTo(String messageID, String reaction) async {
    Map buildData = MessageUpdateBuilder()
        .withUUID(messageID)
        .withType(ClientComponent.MESSAGE_UPDATE_VAL_REACTION)
        .withAction(ClientComponent.ADD_REACTION)
        .withValue(reaction)
        .buildMessage();
    // await ReactionHandler().handle(jsonEncode(buildData), EncryptedClient.getInstance()!.uuid!, keyID: uuid);
    await sendMessageUpdate(buildData);
  }

  Future<void> removeReaction(String messageID, String reaction) async {
    Map buildData = MessageUpdateBuilder()
        .withUUID(messageID)
        .withType(ClientComponent.MESSAGE_UPDATE_VAL_REACTION)
        .withAction(ClientComponent.REMOVE_REACTION)
        .withValue(reaction)
        .buildMessage();
    // await ReactionHandler().handle(jsonEncode(buildData), EncryptedClient.getInstance()!.uuid!, keyID: uuid);
    await sendMessageUpdate(buildData);
  }

  Future<void> markAsDelivered(String messageID) async {
    Map buildData = MessageUpdateBuilder()
        .withUUID(messageID)
        .withType(ClientComponent.MESSAGE_UPDATE_VAL_READ)
        .withAction(ClientComponent.NEW_READ_STATUS)
        .withValue(ClientComponent.READ_STATUS_DELIVERED)
        .buildMessage();
    // await ReadStatusHandler().handle(jsonEncode(buildData), EncryptedClient.getInstance()!.uuid!, keyID: uuid);

    await sendMessageUpdate(buildData);
  }

  Future<void> markAsRead(String messageID) async {
    Map buildData = MessageUpdateBuilder()
        .withUUID(messageID)
        .withType(ClientComponent.MESSAGE_UPDATE_VAL_READ)
        .withAction(ClientComponent.NEW_READ_STATUS)
        .withValue(ClientComponent.READ_STATUS_READ)
        .buildMessage();
    // await ReadStatusHandler().handle(jsonEncode(buildData), EncryptedClient.getInstance()!.uuid!, keyID: uuid);
    await sendMessageUpdate(buildData);
  }

  Future<void> sendFileEncryptionKeyPart() async {
    ELog.i("Sending randInt!");
    Random random = Random();
    int randInt = random.nextInt(50000);
    await ClientKeyManager().updateContact(client.serverUrl, uuid, randInt: randInt);
    await sendDataPacket(jsonEncode({ClientComponent.RAND_INT: randInt}));
  }

  Future<void> sendMessageUpdate(Map map) async {
    await sendDataPacket(jsonEncode(map));
    UpdateNotificationRegistry.getInstance().messageUpdate(this, map[ClientComponent.MESSAGE_UUID]);
  }

  Future<void> updateUsername(String username) async {
    Map data = (await ClientKeyManager().getUserData(client.serverUrl, uuid))!;
    data['username'] = username;
    await ClientKeyManager().updateContact(client.serverUrl, uuid, data: data);
    await init();
    UpdateNotificationRegistry.getInstance().newName(this, username);
  }

  Future<void> updateProfilePicturePath(String path) async {
    Map data = (await ClientKeyManager().getUserData(client.serverUrl, uuid))!;
    data['profile_picture'] = path;
    await ClientKeyManager().updateContact(client.serverUrl, uuid, data: data);
    await init();
    UpdateNotificationRegistry.getInstance().newPicture(this, path);
  }

  Future<void> sendUsernameUpdate(String myNewUsername) async {
    Map map = {ClientComponent.NAME_UPDATE: myNewUsername};
    await sendDataPacket(jsonEncode(map));
  }

  Future<void> sendProfilePictureUpdate(String profilePictureLocalPath) async {
    Directory directory = Directory(GetPath.getInstance().path + Platform.pathSeparator + uuid + Platform.pathSeparator);
    String encryptFile = await EncryptionUtil.encryptFileToPath(profilePictureLocalPath, this, directory.path);
    String? uploadedPath = await FileDownload.uploadFile(encryptFile);
    if (uploadedPath == null) {
      ELog.e("Something went wrong with a file upload! to $uuid");
      return;
    }
    String newLocalCopy =
        directory.path + Platform.pathSeparator + profilePictureLocalPath.substring(profilePictureLocalPath.lastIndexOf(Platform.pathSeparator) + 1);
    await File(profilePictureLocalPath).copy(newLocalCopy);
    await sendDataPacket(jsonEncode({ClientComponent.PROFILE_PICTURE_UPDATE: uploadedPath}));
    UpdateNotificationRegistry.getInstance().newPicture(this, newLocalCopy);
  }

  Future<List<T>?> getMessages<T>(
      T Function(
              {required String sender,
              required String senderName,
              required String messageUuid,
              required int time,
              required String messageContent,
              required Map data})
          builder) async {
    return MessageStorage().getMessages(client.serverUrl, uuid, builder);
  }

  Future<bool> isUserTyping({String? uuid}) async {
    Map? data = await ClientKeyManager().getUserData(client.serverUrl, uuid ?? this.uuid);
    if (data == null) {
      ELog.e("Cannot check if the user is typing, cannot locate user data in table for " + (uuid ?? this.uuid));
      return false;
    }
    if (!data.containsKey('typing')) {
      ELog.e('Cannot find typing data in user data for ' + (uuid ?? this.uuid));
      return false;
    }
    Map typing = data['typing']!;
    if (!typing.containsKey(uuid ?? this.uuid)) {
      ELog.e('User has not typed before therefore they are not typing. ' + (uuid ?? this.uuid));
      return false;
    }
    return DateTime.now().millisecondsSinceEpoch < typing[uuid ?? this.uuid] + MagicNumber.TYPING_TIMEOUT_IN_MS;
  }

  Future<void> sendTypingIndicator() async {
    Map toSend = {ClientComponent.TYPING_INDICATOR: DateTime.now().millisecondsSinceEpoch};
    await sendDataPacket(jsonEncode(toSend));
    UpdateNotificationRegistry.getInstance().typingChange(this);
  }

  Future<void> deleteMessageByID(String messageUUID) async {
    MessageStorage().deleteMessage(client.serverUrl, uuid, messageUUID);
  }

  Future<void> init() async {
    Map data = (await ClientKeyManager().getUserData(client.serverUrl, uuid))!;
    if (data.containsKey("username")) {
      username = data['username'];
    } else {
      username = uuid;
    }
    if (data.containsKey("profile_picture")) {
      profilePicturePath = data['profile_picture'];
    } else {
      profilePicturePath = "null";
    }
    remoteKey = await ClientKeyManager().getRSARemotePublicKey(client.serverUrl, uuid);
    privateKey = await ClientKeyManager().getRSAPrivateKey(client.serverUrl, uuid);
    _createEncrypter();
  }

  Future<int> getLastTime() async {
    int? l = await MessageStorage().getLastMessageTime(client.serverUrl, uuid);
    if (l == null) {
      return 0;
    }
    return l;
  }
}