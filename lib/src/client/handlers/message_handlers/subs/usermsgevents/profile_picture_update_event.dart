import 'dart:convert';
import 'dart:io';

import 'package:mildly_encrypted_package/mildly_encrypted_package.dart';
import 'package:mildly_encrypted_package/src/client/cutil/client_components.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientUser.dart';
import 'package:mildly_encrypted_package/src/logging/ELog.dart';
import 'package:mildly_encrypted_package/src/utils/GetPath.dart';
import 'package:mildly_encrypted_package/src/utils/aes/file_download.dart';
import 'package:mildly_encrypted_package/src/utils/encryption_util.dart';
import 'package:mildly_encrypted_package/src/utils/json_validator.dart';

import '../../message_handler.dart';

class ProfilePictureUpdateEvent implements MessageHandler {
  ClientUser from;
  ProfilePictureUpdateEvent(this.from);

  @override
  bool check(String message, String from, {String? keyID}) {
    return JSONValidate.isValidJSON(message, requiredKeys: [ClientComponent.PROFILE_PICTURE_UPDATE]);
  }

  @override
  void handle(String message, String from, {String? keyID}) async {
    Map map = jsonDecode(message);
    String newPicture = map[ClientComponent.PROFILE_PICTURE_UPDATE];
    String downloadedPath = await FileDownload.downloadFile(newPicture, GetPath.getInstance().path + Platform.pathSeparator + (from));

    ClientUser multSource;
    if (keyID != null) {
      multSource = (await (await ClientManagement.getInstance()).getGroupChat(keyID))!;
    } else {
      multSource = (await (await ClientManagement.getInstance()).getUser(from))!;
    }

    String decryptedPath = await EncryptionUtil.decryptImageToPath(
        downloadedPath, this.from, await multSource.getMultPW(), GetPath.getInstance().path + Platform.pathSeparator + (from));
    await File(downloadedPath).delete();
    ELog.i("Received file to $decryptedPath");
    await this.from.updateProfilePicturePath(decryptedPath);
    await this.from.init();
    CoreEventRegistry().notify(CoreEventType.PROFILE_PICTURE_UPDATE, data: from);
  }

  @override
  String getHandlerName() {
    return "Profile Pic Update";
  }
}
