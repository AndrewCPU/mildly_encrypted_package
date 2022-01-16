import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:encrypt/encrypt.dart';
import 'package:mildly_encrypted_package/mildly_encrypted_package.dart';
import 'package:mildly_encrypted_package/src/client/cutil/client_components.dart';
import 'package:mildly_encrypted_package/src/client/cutil/notification_registry.dart';
import 'package:mildly_encrypted_package/src/client/data/message_storage.dart';
import 'package:mildly_encrypted_package/src/client/objs/message_update_builder.dart';
import 'package:mildly_encrypted_package/src/utils/ClientEncryptionUtil.dart';
import 'package:mildly_encrypted_package/src/utils/GetPath.dart';
import 'package:mildly_encrypted_package/src/utils/aes/file_download.dart';
import 'package:mildly_encrypted_package/src/utils/crypto_utils.dart';
import 'package:mildly_encrypted_package/src/utils/save_file.dart';
import 'package:mildly_encrypted_package/src/utils/string_util.dart';
import 'package:uuid/uuid.dart';

import '../../logging/ELog.dart';
import '../../utils/encryption_util.dart';
import '../../utils/magic_nums.dart';
import '../client.dart';
import '../data/client_key_manager.dart';
import 'package:pointycastle/asymmetric/api.dart' as rsa;

import 'ServerObject.dart';

class ClientUser {
  static Future<ClientUser?> loadUser(EncryptedClient client, String uuid) async {
    ClientKeyManager keyManager = ClientKeyManager();
    if (EncryptedClient.getInstance() != null && EncryptedClient.getInstance()!.uuid == uuid) {
      return null;
    }
    if (!(await keyManager.doesContactExist(client.serverUrl, uuid))) {
      ELog.e("Client does not exist. Cannot be loaded ($uuid)");
      return null;
    }
    ClientUser user = ClientUser.internal(uuid, client);
    await user.init();
    return user;
  }

  Map<String, double> _fileUploadProgress = {};
  Map<String, double> _fileDownloadProgress = {};

  void updateFileUploadProgress(String path, double val) {
    _fileUploadProgress[path] = val;
    UpdateNotificationRegistry().fileUploadProgress(this);
  }

  void updateFileDownloadProgress(String path, double val) {
    _fileDownloadProgress[path] = val;
    UpdateNotificationRegistry().fileDownloadProgress(this);
  }

  String uuid;
  EncryptedClient client;
  String? status;

  ClientUser.internal(this.uuid, this.client);

  late String username;
  late String profilePicturePath;

  rsa.RSAPrivateKey? privateKey;
  rsa.RSAPublicKey? remoteKey;
  late Encrypter encrypter;
  bool _online = false;

  bool get online {
    return _online;
  }

  set online(bool b) {
    _online = b;
    () async {
      Map? data = await ClientKeyManager().getUserData(client.serverUrl, uuid);
      if (data == null) {
        return;
      }
      data['online'] = b;
      await ClientKeyManager().updateContact(client.serverUrl, uuid, data: data);
    }.call();
  }

  void _createEncrypter() {
    encrypter = EncryptionUtil.createEncrypter(remoteKey, privateKey);
  }

  Future<void> deleteChat() async {
    await ClientKeyManager().deleteContact(EncryptedClient.getInstance()!.serverUrl, uuid);
  }

  Future<void> setChatExpirationTime(int timeInMs, {bool sendUpdate = false}) async {
    Map? data = await ClientKeyManager().getUserData(client.serverUrl, uuid);
    if (data == null) {
      ELog.e('Cannot update expiration time. Client data is unavailable for $uuid.');
      return;
    }
    data['expiration'] = timeInMs;
    ClientKeyManager().updateContact(client.serverUrl, uuid, data: data);
    if (sendUpdate) {
      await sendDataPacket(jsonEncode({ClientComponent.EXPIRATION_UPDATE_MS: timeInMs}));
    }
    var v4 = Uuid().v4();

    await MessageStorage().insertMessage(EncryptedClient.getInstance()!.serverUrl, uuid,
        messageUuid: v4,
        senderUuid: 'notification',
        messageContent: "The chat expiration has been set to ${StringUtils.timeIncrement(timeInMs)}",
        messageData: {'notification': true},
        timeMs: DateTime.now().millisecondsSinceEpoch);

    if (this is ClientGroupChat) {
      UpdateNotificationRegistry.getInstance().newMessage((await (await ClientManagement.getInstance()).getGroupChat(uuid))!, v4);
    } else {
      UpdateNotificationRegistry.getInstance().newMessage((await (await ClientManagement.getInstance()).getUser(uuid))!, v4);
    }
  }

  Future<int> getExpirationTime() async {
    Map? data = await ClientKeyManager().getUserData(client.serverUrl, uuid);
    if (data == null) {
      ELog.e('Cannot get expiration time. Client data is unavailable for $uuid. Setting to unexpiring.');
      return -1; // -1 = never
    }
    if (data.containsKey('expiration')) {
      return data['expiration'];
    } else {
      return -1; // -1 = never.
    }
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

    await checkIfNeedProfileUpdate();

    return messageUuid;
  }

  Future<void> checkIfNeedProfileUpdate() async {
    SaveFile _save = await SaveFile.getInstance(path: GetPath.getInstance().path + "/data.json");

    if (!_save.containsKey(uuid)) {
      await sendUsernameUpdate(client.getMyUsername());
      await sendProfilePictureUpdate(client.getMyProfilePicturePath());
      await _save.setString(uuid, 'sent!');
    }
  }

  Future<void> sendDataPacket(String message) async {
    List<String> encryptedBlocks = await EncryptionUtil.toEncryptedPieces(message, encrypter);
    Map send = {
      MagicNumber.MESSAGE_COMPILATION: encryptedBlocks,
      MagicNumber.TO_USER: [uuid]
    }; // user encrypted data
    String toSendJson = jsonEncode(send);
    //check that we are authenticated before trying to send data packet. if we're not queue the message and wait for reconnect to go through
    if (!EncryptedClient.getInstance()!.isConnected() || !EncryptedClient.getInstance()!.isAuthenticated()) {
      client.offlineQueue.add(toSendJson);
      await client.reconnect();
    } else {
      ServerObject obj = await ServerObject.getInstance(client);
      await obj.sendMessage(toSendJson);
    }
  }

  Future<void> sendStatusUpdate(String status) async {
    sendDataPacket(jsonEncode({ClientComponent.STATUS_UPDATE: status}));
  }

  Future<int> getRandInt() async {
    return int.parse(await ClientKeyManager().getColumnData(client.serverUrl, uuid, 'rand_key'));
  }

  Future<int> getRemoteRandInt() async {
    return int.parse(await ClientKeyManager().getColumnData(client.serverUrl, uuid, 'remote_rand_key'));
  }

  Future<String> decryptFromUser(List<String> messageParts) async {
    return await EncryptionUtil.decryptParts(messageParts, encrypter);
  }

  Future<void> sendFile(String path) async {
    Directory directory = Directory(GetPath.getInstance().path + Platform.pathSeparator + uuid);
    String encryptFile = await ClientEncryptionUtil.encryptFileToPath(path, this, await getMultPW(), directory.path);
    String? uploadedPath = await FileDownload.uploadFile(encryptFile, uploadProgress: (val) {
      updateFileUploadProgress(path, val);
    });
    _fileUploadProgress.remove(path);
    if (uploadedPath == null) {
      ELog.e("Something went wrong with a file upload! to $uuid");
      return;
    }
    String newLocalCopy = directory.path + path.substring(path.lastIndexOf(Platform.pathSeparator));
    await File(path).copy(newLocalCopy);
    await sendChatMessage('', specialData: {ClientComponent.FILE_URL: uploadedPath}, localDifference: {ClientComponent.FILE_URL: newLocalCopy});
  }

  double getSendProgress() {
    double val = 0.0;
    for (String key in _fileUploadProgress.keys) {
      val += _fileUploadProgress[key]!;
    }
    if (val == 0.0) {
      return 0.0;
    } else {
      val /= _fileUploadProgress.keys.length;
      return val;
    }
  }

  Future<void> acceptReactionAddition(String uuidReacting, String messageID, String reaction) async {
    Map? currentMessageData = await MessageStorage().getMessage<Map>(
        client.serverUrl, uuid, messageID, ({required data, required messageContent, required messageUuid, required sender, required time}) => data);
    if (currentMessageData == null) {
      ELog.e("Received update request for a message that does not exist. $uuidReacting > $messageID");
      return;
    }
    Map reactions = {};
    if (currentMessageData.containsKey('reactions')) {
      reactions = currentMessageData['reactions'];
    }
    reactions[uuidReacting] = reaction;
    currentMessageData['reactions'] = reactions;
    await MessageStorage().updateMessage(client.serverUrl, uuid, messageID, currentMessageData);
  }

  Future<void> acceptReactionRemoval(String uuidReacting, String messageID, String reaction) async {
    Map? currentMessageData = await MessageStorage().getMessage<Map>(
        client.serverUrl, uuid, messageID, ({required data, required messageContent, required messageUuid, required sender, required time}) => data);
    if (currentMessageData == null) {
      ELog.e("Received update request for a message that does not exist. $uuidReacting > $messageID");
      return;
    }
    Map reactions = {};
    if (currentMessageData.containsKey('reactions')) {
      reactions = currentMessageData['reactions'];
    }
    if (reactions.containsKey(uuidReacting)) {
      reactions.remove(uuidReacting);
    }
    currentMessageData['reactions'] = reactions;

    await MessageStorage().updateMessage(client.serverUrl, uuid, messageID, currentMessageData);
  }

  Future<void> acceptReadReceiptChange(String uuidRead, String messageID, String state) async {
    Map? currentMessageData = await MessageStorage().getMessage<Map>(
        client.serverUrl, uuid, messageID, ({required data, required messageContent, required messageUuid, required sender, required time}) => data);
    if (currentMessageData == null) {
      ELog.e("Received update request for a message that does not exist. $uuidRead > $messageID");
      return;
    }
    Map reads = {};
    if (currentMessageData.containsKey('read_status')) {
      reads = currentMessageData['read_status'];
    }
    if (reads.containsKey(uuidRead)) {
      if (reads[uuidRead] == ClientComponent.READ_STATUS_READ) {
        ELog.i("Blocking database update for read status. User has already read this message");
        return;
      }
    }
    reads[uuidRead] = state;
    currentMessageData['read_status'] = reads;
    if (await getExpirationTime() != -1 && reads[uuidRead] == ClientComponent.READ_STATUS_READ) {
      currentMessageData['expires'] = DateTime.now().millisecondsSinceEpoch + await getExpirationTime();
    }
    await MessageStorage().updateMessage(client.serverUrl, uuid, messageID, currentMessageData);
  }

  Future<void> reactTo(String messageID, String reaction) async {
    Map buildData = MessageUpdateBuilder()
        .withUUID(messageID)
        .withType(ClientComponent.MESSAGE_UPDATE_VAL_REACTION)
        .withAction(ClientComponent.ADD_REACTION)
        .withValue(reaction)
        .buildMessage();
    await acceptReactionRemoval(client.uuid!, messageID, '');
    await acceptReactionAddition(client.uuid!, messageID, reaction);
    await sendMessageUpdate(buildData);
  }

  Future<void> removeReaction(String messageID, String reaction) async {
    Map buildData = MessageUpdateBuilder()
        .withUUID(messageID)
        .withType(ClientComponent.MESSAGE_UPDATE_VAL_REACTION)
        .withAction(ClientComponent.REMOVE_REACTION)
        .withValue(reaction)
        .buildMessage();
    await acceptReactionRemoval(client.uuid!, messageID, '');
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
    await acceptReadReceiptChange(client.uuid!, messageID, ClientComponent.READ_STATUS_DELIVERED);
    await sendMessageUpdate(buildData);
  }

  Future<void> markAsRead(String messageID) async {
    Map buildData = MessageUpdateBuilder()
        .withUUID(messageID)
        .withType(ClientComponent.MESSAGE_UPDATE_VAL_READ)
        .withAction(ClientComponent.NEW_READ_STATUS)
        .withValue(ClientComponent.READ_STATUS_READ)
        .buildMessage();
    await acceptReadReceiptChange(client.uuid!, messageID, ClientComponent.READ_STATUS_READ);
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
    String encryptFile = await ClientEncryptionUtil.encryptFileToPath(profilePictureLocalPath, this, await getMultPW(), directory.path);
    String? uploadedPath = await FileDownload.uploadFile(encryptFile);
    if (uploadedPath == null) {
      ELog.e("Something went wrong with a file upload! to $uuid");
      return;
    }
    String newLocalCopy = directory.path + profilePictureLocalPath.substring(profilePictureLocalPath.lastIndexOf(Platform.pathSeparator) + 1);
    await File(profilePictureLocalPath).copy(newLocalCopy);
    await sendDataPacket(jsonEncode({ClientComponent.PROFILE_PICTURE_UPDATE: uploadedPath}));
    UpdateNotificationRegistry.getInstance().newPicture(this, newLocalCopy);
  }

  Future<List<T>?> getMessages<T>(
      T Function({required ClientUser? sender, required String messageUuid, required int time, required String messageContent, required Map data})
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
      // ELog.e('Cannot find typing data in user data for ' + (uuid ?? this.uuid));
      return false;
    }
    Map typing = data['typing']!;
    if (!typing.containsKey(uuid ?? this.uuid)) {
      // ELog.e('User has not typed before therefore they are not typing. ' + (uuid ?? this.uuid));
      return false;
    }
    return DateTime.now().millisecondsSinceEpoch < typing[uuid ?? this.uuid] + MagicNumber.TYPING_TIMEOUT_IN_MS;
  }

  Future<void> setMessageSize(String messageUUID, double width, double height) async {
    Map? data = await MessageStorage().getMessage(
        client.serverUrl, uuid, messageUUID, ({required data, required messageContent, required messageUuid, required sender, required time}) => data);
    if (data == null) {
      ELog.e("Cannot update size of non existant message.");
      return;
    }
    data['width'] = width.toInt();
    data['height'] = height.toInt();
    await MessageStorage().updateMessage(client.serverUrl, uuid, messageUUID, data);
  }

  Future<void> setMessageThumbnail(String messageUUID, String thumbnailPath) async {
    Map? data = await MessageStorage().getMessage(
        client.serverUrl, uuid, messageUUID, ({required data, required messageContent, required messageUuid, required sender, required time}) => data);
    if (data == null) {
      ELog.e("Cannot update thumbnail of non existant message.");
      return;
    }
    data['thumb'] = thumbnailPath;
    await MessageStorage().updateMessage(client.serverUrl, uuid, messageUUID, data);
  }

  Future<void> sendTypingIndicator() async {
    Map toSend = {ClientComponent.TYPING_INDICATOR: DateTime.now().millisecondsSinceEpoch};
    await sendDataPacket(jsonEncode(toSend));
    UpdateNotificationRegistry.getInstance().typingChange(this);
  }

  Future<void> deleteMessageByID(String messageUUID) async {
    await MessageStorage().deleteMessage(client.serverUrl, uuid, messageUUID);
    UpdateNotificationRegistry.getInstance().newMessage(this, messageUUID);
  }

  Future<int> getMultPW() async {
    int mult = (CryptoUtils.encodeRSAPublicKeyToPem(remoteKey as rsa.RSAPublicKey).hashCode *
        (await ClientKeyManager().getColumnData(client.serverUrl, uuid, 'public_key')).hashCode);
    mult += (await getRandInt() * await getRemoteRandInt());
    return mult;
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

    if (data.containsKey('status')) {
      status = data['status'];
    } else {
      status = '';
    }

    if (data.containsKey('online')) {
      _online = data['online'];
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
