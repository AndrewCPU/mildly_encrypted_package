import 'dart:convert';

import 'package:mildly_encrypted_package/mildly_encrypted_package.dart';
import 'package:mildly_encrypted_package/src/client/cutil/client_components.dart';
import 'package:mildly_encrypted_package/src/client/cutil/notification_registry.dart';
import 'package:mildly_encrypted_package/src/client/data/message_storage.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/message_handler.dart';
import 'package:mildly_encrypted_package/src/logging/ELog.dart';
import 'package:mildly_encrypted_package/src/utils/json_validator.dart';

class ReadStatusHandler implements MessageHandler {
  @override
  bool check(String message, String from, {String? keyID}) {
    return JSONValidate.isValidJSON(message, requiredKeys: [ClientComponent.NEW_READ_STATUS]);
  }

  @override
  String getHandlerName() {
    return "New Read Status Handler";
  }

  @override
  Future<void> handle(String message, String from, {String? keyID}) async {
    Map map = jsonDecode(message);
    String newStatus = map[ClientComponent.NEW_READ_STATUS];
    String messageUuid = map[ClientComponent.MESSAGE_UUID];
    String serverIP = EncryptedClient.getInstance()!.serverUrl;
    String chatID = keyID ?? from;
    Map? currentMessageData = await MessageStorage().getMessage<Map>(
        serverIP, chatID, messageUuid, ({required data, required messageContent, required messageUuid, required sender, required time}) => data);
    if (currentMessageData == null) {
      ELog.e("Received update request for a message that does not exist. $from > $messageUuid");
      return;
    }
    Map reads = {};
    if (currentMessageData.containsKey('read_status')) {
      reads = currentMessageData['read_status'];
    }
    if (reads.containsKey(from)) {
      if (reads[from] == ClientComponent.READ_STATUS_READ) {
        ELog.i("Blocking database update for read status. User has already read this message");
        return;
      }
    }
    reads[from] = newStatus;
    currentMessageData['read_status'] = reads;
    await MessageStorage().updateMessage(serverIP, chatID, messageUuid, currentMessageData);
    if (keyID != null) {
      UpdateNotificationRegistry.getInstance().messageUpdate((await ClientManagement.getInstance().getGroupChat(keyID))!, messageUuid);
    } else {
      UpdateNotificationRegistry.getInstance().messageUpdate((await ClientManagement.getInstance().getUser(from))!, messageUuid);
    }
  }
}
