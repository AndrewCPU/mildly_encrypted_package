import 'dart:convert';

import 'package:mildly_encrypted_package/mildly_encrypted_package.dart';
import 'package:mildly_encrypted_package/src/client/cutil/client_components.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/message_handler.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientUser.dart';
import 'package:mildly_encrypted_package/src/client/objs/encryption_pack.dart';
import 'package:mildly_encrypted_package/src/utils/json_validator.dart';

class NameUpdateEvent implements MessageHandler {
  ClientUser from;
  NameUpdateEvent(this.from);

  @override
  bool check(String message, String from, {String? keyID}) {
    return JSONValidate.isValidJSON(message, requiredKeys: [ClientComponent.NAME_UPDATE]);
  }

  @override
  void handle(String message, String from, {String? keyID}) async {
    Map map = jsonDecode(message);
    String newName = map[ClientComponent.NAME_UPDATE];
    await this.from.updateUsername(newName);
    await this.from.init();
    CoreEventRegistry().notify(CoreEventType.NAME_UPDATE, data: from);
  }

  @override
  String getHandlerName() {
    return "Name Update Handler";
  }
}
