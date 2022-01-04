import 'dart:convert';

import 'package:mildly_encrypted_package/mildly_encrypted_package.dart';
import 'package:mildly_encrypted_package/src/client/cutil/core/CoreEventType.dart';
import 'package:mildly_encrypted_package/src/client/cutil/core/core_event_registry.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/message_handler.dart';
import 'package:mildly_encrypted_package/src/utils/json_validator.dart';

class KeyExchangeCompleteEvent implements MessageHandler {
  @override
  bool check(String message, String from, {String? keyID}) {
    return JSONValidate.isValidJSON(message, requiredKeys: [ClientComponent.KEY_EXCHANGE_COMPLETE]);
  }

  @override
  String getHandlerName() {
    return "Completed Key Exchange Event";
  }

  @override
  void handle(String message, String from, {String? keyID}) async {
    Map map = jsonDecode(message);
    ClientUser clientUser = ((await (await ClientManagement.getInstance()).getUser(from))!);
    await clientUser.sendProfilePictureUpdate(EncryptedClient.getInstance()!.getMyProfilePicturePath());
    await clientUser.sendUsernameUpdate(EncryptedClient.getInstance()!.getMyUsername());
    CoreEventRegistry().notify(CoreEventType.KEY_EXCHANGE_COMPLETE, data: from);
  }
}
