import 'dart:convert';

import 'package:mildly_encrypted_package/mildly_encrypted_package.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/message_handler.dart';
import 'package:mildly_encrypted_package/src/client/objs/ServerObject.dart';
import 'package:mildly_encrypted_package/src/utils/json_validator.dart';
import 'package:mildly_encrypted_package/src/utils/magic_nums.dart';

class OnlineStatusHandler implements MessageHandler {
  @override
  bool check(String message, String from, {String? keyID}) {
    return (JSONValidate.isValidJSON(message, requiredKeys: [MagicNumber.ONLINE, MagicNumber.ACTIVE]));
  }

  @override
  String getHandlerName() {
    return "Online Status Handler";
  }

  @override
  void handle(String message, String from, {String? keyID}) async {
    Map json = jsonDecode(message);
    String userIDInRef = json[MagicNumber.ONLINE];
    bool isOnline = json[MagicNumber.ACTIVE];
    ClientUser? user = await (await ClientManagement.getInstance()).getUser(userIDInRef);
    if (user == null) {
      return;
    }
    bool originalVal = user.online;
    if (originalVal != isOnline) {
      user.online = isOnline;
      CoreEventRegistry().notify(CoreEventType.NAME_UPDATE, data: user.uuid);
    }
  }
}
