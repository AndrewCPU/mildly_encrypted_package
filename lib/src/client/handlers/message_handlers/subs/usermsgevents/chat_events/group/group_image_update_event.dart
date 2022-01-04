import 'dart:convert';
import 'dart:io';

import 'package:mildly_encrypted_package/mildly_encrypted_package.dart';
import 'package:mildly_encrypted_package/src/client/cutil/client_components.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/message_handler.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientGroupChat.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientManagement.dart';
import 'package:mildly_encrypted_package/src/logging/ELog.dart';
import 'package:mildly_encrypted_package/src/utils/GetPath.dart';
import 'package:mildly_encrypted_package/src/utils/aes/file_download.dart';
import 'package:mildly_encrypted_package/src/utils/encryption_util.dart';
import 'package:mildly_encrypted_package/src/utils/json_validator.dart';

class GroupImageUpdateEvent implements MessageHandler {
  @override
  bool check(String message, String from, {String? keyID}) {
    return JSONValidate.isValidJSON(message, requiredKeys: [ClientComponent.GROUP_IMAGE_UPDATE]) && keyID != null;
  }

  @override
  String getHandlerName() {
    return "Group Image Update Event";
  }

  @override
  void handle(String message, String from, {String? keyID}) async {
    Map map = jsonDecode(message);
    String newImageURL = map[ClientComponent.GROUP_IMAGE_UPDATE];
    ClientGroupChat? group = ((await (await ClientManagement.getInstance()).getGroupChat(keyID!)));

    if (group == null) {
      ELog.e("Cannot find group to update name.");
      return;
    }
    String downloadedPath = await FileDownload.downloadFile(newImageURL, keyID, GetPath.getInstance().path + Platform.pathSeparator + (keyID));
    String decryptedPath = await EncryptionUtil.decryptImageToPath(downloadedPath, group, GetPath.getInstance().path + Platform.pathSeparator + (keyID));
    await File(downloadedPath).delete();
    ELog.i("Received file to $decryptedPath");
    await group.updateProfilePicturePath(decryptedPath);
    await group.init();
    CoreEventRegistry().notify(CoreEventType.PROFILE_PICTURE_UPDATE, data: from);
  }
}
