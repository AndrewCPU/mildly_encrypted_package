import 'dart:convert';
import 'dart:io';

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
    String downloadedPath = await FileDownload.downloadFile(newPicture, from, GetPath.getInstance().path + Platform.pathSeparator + (from));
    String decryptedPath = await EncryptionUtil.decryptImageToPath(downloadedPath, this.from, GetPath.getInstance().path + Platform.pathSeparator + (from));
    await File(downloadedPath).delete();
    ELog.i("Received file to $decryptedPath");
    await this.from.updateProfilePicturePath(decryptedPath);
    await this.from.init();
  }

  @override
  String getHandlerName() {
    return "Profile Pic Update";
  }
}
