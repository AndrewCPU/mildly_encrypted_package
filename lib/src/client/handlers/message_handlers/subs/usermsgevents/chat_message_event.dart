import 'dart:convert';
import 'dart:io';

import 'package:mildly_encrypted_package/mildly_encrypted_package.dart';
import 'package:mildly_encrypted_package/src/client/cutil/client_components.dart';
import 'package:mildly_encrypted_package/src/client/cutil/notification_registry.dart';
import 'package:mildly_encrypted_package/src/client/data/client_key_manager.dart';
import 'package:mildly_encrypted_package/src/client/data/message_storage.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/message_handler.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientUser.dart';
import 'package:mildly_encrypted_package/src/client/objs/encryption_pack.dart';
import 'package:mildly_encrypted_package/src/logging/ELog.dart';
import 'package:mildly_encrypted_package/src/utils/GetPath.dart';
import 'package:mildly_encrypted_package/src/utils/aes/file_download.dart';
import 'package:mildly_encrypted_package/src/utils/encryption_util.dart';
import 'package:mildly_encrypted_package/src/utils/json_validator.dart';

class ChatMessageEvent implements MessageHandler {
  ClientUser from;
  ChatMessageEvent(this.from);

  @override
  bool check(String message, String from, {String? keyID}) {
    return JSONValidate.isValidJSON(message, requiredKeys: [ClientComponent.MESSAGE_CONTENT, ClientComponent.MESSAGE_METADATA]);
  }

  @override
  void handle(String message, String from, {String? keyID}) async {
    Map map = jsonDecode(message);
    String messageContent = map[ClientComponent.MESSAGE_CONTENT];
    Map messageMetaData = map[ClientComponent.MESSAGE_METADATA];
    String messageUuid = messageMetaData[ClientComponent.MESSAGE_UUID];
    int timeMs = messageMetaData[ClientComponent.TIME];
    messageMetaData.remove(ClientComponent.MESSAGE_UUID);
    messageMetaData.remove(ClientComponent.TIME);

    ClientUser multSource;
    if (keyID != null) {
      multSource = ((await (await ClientManagement.getInstance()).getGroupChat(keyID))!);
    } else {
      multSource = ((await (await ClientManagement.getInstance()).getUser(from))!);
    }

    if (messageMetaData.containsKey(ClientComponent.FILE_URL)) {
      String url = messageMetaData[ClientComponent.FILE_URL];
      String downloadedPath =
          await FileDownload.downloadFile(url, GetPath.getInstance().path + Platform.pathSeparator + (keyID ?? from), downloadProgress: (val) {
        // multSource.fileDownloadProgress[url] = val;
            multSource.updateFileDownloadProgress(url, val);
      });
      // multSource.fileDownloadProgress.remove(url);
      print(downloadedPath);
      String decryptedPath = await EncryptionUtil.decryptImageToPath(downloadedPath, this.from, await multSource.getMultPW(),
          GetPath.getInstance().path + Platform.pathSeparator + (keyID ?? from) + Platform.pathSeparator);
      print(decryptedPath);
      await File(downloadedPath).delete();
      messageMetaData[ClientComponent.FILE_URL] = decryptedPath;
      ELog.i("Received file to $decryptedPath");
    }
    await MessageStorage().insertMessage(EncryptedClient.getInstance()!.serverUrl, keyID ?? from,
        messageUuid: messageUuid, senderUuid: from, messageContent: messageContent, messageData: messageMetaData, timeMs: timeMs);
    if (keyID != null) {
      UpdateNotificationRegistry.getInstance().newMessage((await (await ClientManagement.getInstance()).getGroupChat(keyID))!, messageUuid);
    } else {
      UpdateNotificationRegistry.getInstance().newMessage((await (await ClientManagement.getInstance()).getUser(from))!, messageUuid);
    }

    Map data = (await ClientKeyManager().getUserData(this.from.client.serverUrl, keyID ?? from))!;
    Map typing = {};
    if (data.containsKey('typing')) {
      typing = data['typing'];
      if (typing.containsKey(from)) {
        int lastTyping = typing[from];
        if (timeMs > lastTyping) {
          ELog.i("User still had active typing indicator from before message was received. Removing it.");
          typing[from] = 0;
          data['typing'] = typing;
          await ClientKeyManager().updateContact(EncryptedClient.getInstance()!.serverUrl, keyID ?? from, data: data);
        }
      }
    }

    if (EncryptedClient.getInstance() != null && EncryptedClient.getInstance()!.notificationCallback != null) {
      ClientUser fromUser = (await (await ClientManagement.getInstance()).getUser(from))!;
      EncryptedClient.getInstance()!.notificationCallback!(fromUser.profilePicturePath, fromUser.username, fromUser.uuid,
          messageMetaData.containsKey(ClientComponent.FILE_URL) ? 'Sent a file' : messageContent);
    }

    await (await (await ClientManagement.getInstance()).getFromUUID(keyID ?? from))?.markAsDelivered(messageUuid);
    ELog.i("Received $messageContent from $from with metaData $messageMetaData" + (keyID != null ? " in Group Chat $keyID" : ""));
  }

  @override
  String getHandlerName() {
    return "Chat Message Handler";
  }
}
