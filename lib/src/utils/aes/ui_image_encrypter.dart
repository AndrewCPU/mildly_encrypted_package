import 'dart:io';

import 'package:aes_crypt_null_safe/aes_crypt_null_safe.dart';
import 'package:flutter/foundation.dart';
import 'package:mildly_encrypted_package/src/client/data/client_key_manager.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientUser.dart';
import 'package:mildly_encrypted_package/src/utils/aes/image_encrypter.dart';
import 'package:uuid/uuid.dart';

String computeImage(List<String> l) {
  String path = l[0];
  int mult = int.parse(l[1]);
  String saveDirectory = (l[2]);
  var crypt = AesCrypt();

  crypt.setPassword(mult.toString());
  crypt.setOverwriteMode(AesCryptOwMode.on);

  String targetPath = (saveDirectory) + Uuid().v4() + ".aes";
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
  crypt.decryptFileSync(path, (saveDirectory) + Platform.pathSeparator + fileName.replaceAll(".aes", ""));
  return (saveDirectory) + Platform.pathSeparator + fileName.replaceAll(".aes", "");
}

class ImageEncrypter implements ImageEncrypterMod {
  @override
  Future<String> encryptImage(String filePath, ClientUser clientUser, String targetDirectory) async {
    int myRandInt = await clientUser.getRandInt();
    int otherRandInt = await clientUser.getRemoteRandInt();
    int mult = (await ClientKeyManager().getColumnData(clientUser.client.serverUrl, clientUser.uuid, 'public_key')).hashCode *
        (await ClientKeyManager().getColumnData(clientUser.client.serverUrl, clientUser.uuid, 'remote_public_key')).hashCode;
    mult += (otherRandInt * myRandInt);
    String targetPath = await compute(computeImage, [filePath, mult.toString(), targetDirectory]);
    return targetPath;
  }

  @override
  Future<String> decryptImageToPath(String filePath, ClientUser clientUser, String targetDirectory) async {
    int myRandInt = await clientUser.getRandInt();
    int otherRandInt = await clientUser.getRemoteRandInt();
    int mult = (await ClientKeyManager().getColumnData(clientUser.client.serverUrl, clientUser.uuid, 'public_key')).hashCode *
        (await ClientKeyManager().getColumnData(clientUser.client.serverUrl, clientUser.uuid, 'remote_public_key')).hashCode;
    mult += (otherRandInt * myRandInt);
    return await compute(computeDecrypt, [filePath, mult.toString(), targetDirectory]);
  }
}
