import 'dart:io';

import 'package:aes_crypt_null_safe/aes_crypt_null_safe.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mildly_encrypted_package/src/client/data/client_key_manager.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientUser.dart';
import 'package:mildly_encrypted_package/src/utils/aes/image_encrypter.dart';
import 'package:mime/mime.dart';
import 'package:quick_load_thumbnail/quick_load_thumbnail.dart';
import 'package:uuid/uuid.dart';

String computeImage(List<String> l) {
  String path = l[0];
  int mult = int.parse(l[1]);
  String saveDirectory = (l[2]);
  var crypt = AesCrypt();
  crypt.setPassword(mult.toString());
  crypt.setOverwriteMode(AesCryptOwMode.on);
  if (!saveDirectory.endsWith(Platform.pathSeparator)) {
    saveDirectory += Platform.pathSeparator;
  }
  String targetPath = (saveDirectory) + path.split('/').last + ".aes";
  print(targetPath);
  File file = File(targetPath);
  if (!(file.existsSync())) {
    file.createSync(recursive: true);
  }
  crypt.encryptFileSync(path, targetPath);
  return targetPath;
}

String computeDecrypt(List<String> args) {
  String path = args[0];
  int mult = int.parse(args[1]);
  String saveDirectory = (args[2]);
  var crypt = AesCrypt();
  crypt.setPassword(mult.toString());
  crypt.setOverwriteMode(AesCryptOwMode.on);
  String fileName = path.split(Platform.pathSeparator).last;
  File file = File((saveDirectory) + Platform.pathSeparator + fileName.substring(0, fileName.lastIndexOf(".")));
  if (!(file.existsSync())) {
    file.createSync(recursive: true);
  }
  crypt.decryptFileSync(path, file.path);

  return file.path;
}

class ImageEncrypter implements ImageEncrypterMod {
  @override
  Future<String> encryptImage(String filePath, ClientUser clientUser, int mult, String targetDirectory) async {
    String targetPath = await compute(computeImage, [filePath, mult.toString(), targetDirectory]);
    return targetPath;
  }

  @override
  Future<String> decryptImageToPath(String filePath, ClientUser clientUser, int mult, String targetDirectory) async {
    String decryptedPath = await compute(computeDecrypt, [filePath, mult.toString(), targetDirectory]);
    return decryptedPath;
  }
}
