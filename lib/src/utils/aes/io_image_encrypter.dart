import 'dart:io';

import 'package:aes_crypt_null_safe/aes_crypt_null_safe.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientUser.dart';
import 'package:mildly_encrypted_package/src/utils/aes/image_encrypter.dart';

class ImageEncrypter implements ImageEncrypterMod {
  @override
  Future<String> encryptImage(String filePath, ClientUser clientUser, int mult, String targetDirectory) async {
    String path = filePath;
    String saveDirectory = targetDirectory;
    if (!saveDirectory.endsWith(Platform.pathSeparator)) {
      saveDirectory += Platform.pathSeparator;
    }

    var crypt = AesCrypt();
    crypt.setPassword(mult.toString());
    crypt.setOverwriteMode(AesCryptOwMode.on);
    if (!saveDirectory.endsWith(Platform.pathSeparator)) {
      saveDirectory += Platform.pathSeparator;
    }
    String targetPath = (saveDirectory) + path.split('/').last + ".aes";
    print(targetPath);
    File file = File(targetPath);
    if (!(await (file.exists()))) {
      await file.create(recursive: true);
    }
    await crypt.encryptFile(path, targetPath);
    return targetPath;
  }

  @override
  Future<String> decryptImageToPath(String filePath, ClientUser clientUser, int mult, String targetDirectory) async {
    String path = filePath;
    String saveDirectory = targetDirectory;
    if (!saveDirectory.endsWith(Platform.pathSeparator)) {
      saveDirectory += Platform.pathSeparator;
    }
    var crypt = AesCrypt();
    crypt.setPassword(mult.toString());
    crypt.setOverwriteMode(AesCryptOwMode.on);
    String fileName = path.split(Platform.pathSeparator).last;
    File file = File((saveDirectory) + Platform.pathSeparator + fileName.substring(0, fileName.lastIndexOf(".")));
    if ((!(await file.exists()))) {
      await file.create(recursive: true);
    }
    await crypt.decryptFile(path, file.path);
    return file.path;
  }
}
