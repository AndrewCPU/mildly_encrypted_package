import 'dart:convert';

import 'package:mildly_encrypted_package/src/client/cutil/client_components.dart';
import 'package:mildly_encrypted_package/src/client/cutil/core/CoreEventType.dart';
import 'package:mildly_encrypted_package/src/client/cutil/core/core_event_registry.dart';
import 'package:mildly_encrypted_package/src/client/data/client_key_manager.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/message_handler.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientManagement.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientUser.dart';
import 'package:mildly_encrypted_package/src/logging/ELog.dart';
import 'package:mildly_encrypted_package/src/utils/json_validator.dart';

import '../../../../client.dart';

class StatusUpdateEvent implements MessageHandler {
  @override
  bool check(String message, String from, {String? keyID}) {
    return JSONValidate.isValidJSON(message, requiredKeys: [ClientComponent.STATUS_UPDATE]);
  }

  @override
  String getHandlerName() {
    return "Status Update Handler";
  }

  @override
  void handle(String message, String from, {String? keyID}) async {
    Map json = jsonDecode(message);
    ClientUser? fromUser = await (await ClientManagement.getInstance()).getUser(from);
    if (fromUser == null) {
      ELog.e("Cannot update user status if user is  null.");
      return;
    }
    Map? data = await ClientKeyManager().getUserData(EncryptedClient.getInstance()!.serverUrl, from);
    if (data == null) {
      ELog.e("Cannot update status if user data is null.");
      return;
    }
    data['status'] = json[ClientComponent.STATUS_UPDATE];
    fromUser.status = json[ClientComponent.STATUS_UPDATE];
    await ClientKeyManager().updateContact(EncryptedClient.getInstance()!.serverUrl, from, data: data);
    CoreEventRegistry().notify(CoreEventType.NAME_UPDATE, data: from);
  }
}
