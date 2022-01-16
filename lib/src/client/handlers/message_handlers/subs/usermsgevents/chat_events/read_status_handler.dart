import 'dart:convert';

import 'package:mildly_encrypted_package/src/client/cutil/client_components.dart';
import 'package:mildly_encrypted_package/src/client/cutil/notification_registry.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/message_handler.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientManagement.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientUser.dart';
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
    ClientUser? user;
    if (keyID != null) {
      user = (await (await ClientManagement.getInstance()).getGroupChat(keyID))!;
    } else {
      user = (await (await ClientManagement.getInstance()).getUser(from))!;
    }
    await user.acceptReadReceiptChange(from, messageUuid, newStatus);
    UpdateNotificationRegistry.getInstance().messageUpdate(user, messageUuid);
  }
}
