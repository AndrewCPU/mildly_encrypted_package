import 'dart:io';

import 'package:aes_crypt_null_safe/aes_crypt_null_safe.dart';
import 'package:mildly_encrypted_package/src/client/data/client_key_manager.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientUser.dart';
import 'package:mildly_encrypted_package/src/utils/aes/image_encrypter.dart';
import 'package:uuid/uuid.dart';

class ImageEncrypter implements ImageEncrypterMod {
  @override
  Future<String> encryptImage(String filePath, ClientUser clientUser, String targetDirectory) async {
    String path = filePath;
    int myRandInt = await clientUser.getRandInt();
    int otherRandInt = await clientUser.getRemoteRandInt();
    int mult = (await ClientKeyManager().getColumnData(clientUser.client.serverUrl, clientUser.uuid, 'public_key')).hashCode *
        (await ClientKeyManager().getColumnData(clientUser.client.serverUrl, clientUser.uuid, 'remote_public_key')).hashCode;
    mult += (otherRandInt * myRandInt);
    String saveDirectory = targetDirectory;
    var crypt = AesCrypt();

    crypt.setPassword(mult.toString());
    crypt.setOverwriteMode(AesCryptOwMode.on);
    if (!(await (Directory(saveDirectory).exists()))) {
      await Directory(saveDirectory).create(recursive: true);
    }
    String targetPath = (saveDirectory) + Uuid().v4() + ".aes";
    await crypt.encryptFile(path, targetPath);
    return targetPath;
  }

  @override
  Future<String> decryptImageToPath(String filePath, ClientUser clientUser, String targetDirectory) async {
    int myRandInt = await clientUser.getRandInt();
    int otherRandInt = await clientUser.getRemoteRandInt();
    int mult = (await ClientKeyManager().getColumnData(clientUser.client.serverUrl, clientUser.uuid, 'public_key')).hashCode *
        (await ClientKeyManager().getColumnData(clientUser.client.serverUrl, clientUser.uuid, 'remote_public_key')).hashCode;
    mult += (otherRandInt * myRandInt);
    String path = filePath;
    String saveDirectory = targetDirectory;
    var crypt = AesCrypt();
    crypt.setPassword(mult.toString());
    crypt.setOverwriteMode(AesCryptOwMode.on);
    String fileName = path.split(Platform.pathSeparator).last;
    String targetPath = ((saveDirectory) + Platform.pathSeparator + fileName.replaceAll(".aes", ""));
    await Directory(saveDirectory).create(recursive: true);
    await File(targetPath).create(recursive: true);
    await crypt.decryptFile(path, targetPath);
    return targetPath;
  }
}
