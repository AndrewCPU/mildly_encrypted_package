import 'dart:io';

import 'package:aes_crypt_null_safe/aes_crypt_null_safe.dart';
import 'package:encrypt/encrypt.dart';
import 'package:mildly_encrypted_package/src/client/data/client_key_manager.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientUser.dart';
import 'package:mildly_encrypted_package/src/utils/aes/encrypt_image.dart';
import 'package:mildly_encrypted_package/src/utils/rsa/encrypt_text.dart';
import 'package:mildly_encrypted_package/src/utils/rsa/io_rsa_encrypter.dart';
import 'package:pointycastle/asymmetric/api.dart' as rsa;
import 'package:pointycastle/api.dart' as asym;

import '../logging/ELog.dart';
import 'crypto_utils.dart';
import 'key_type.dart';

class EncryptionUtil {
  static Future<String> encryptFileToPath(String filePath, ClientUser clientUser, int mult, String targetDirectory) async {
    return await EncryptImage.getImageEncrypter().encryptImage(filePath, clientUser, mult, targetDirectory);
  }

  static Future<String> decryptImageToPath(String filePath, ClientUser clientUser, int mult, String targetDirectory) async {
    return await EncryptImage.getImageEncrypter().decryptImageToPath(filePath, clientUser, mult, targetDirectory);
  }

  static bool isKeyValid(KeyType type, String pemKey) {
    try {
      if (type == KeyType.public) {
        var key = CryptoUtils.rsaPublicKeyFromPem(pemKey);
      } else {
        var key = CryptoUtils.rsaPrivateKeyFromPem(pemKey);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  static Encrypter createEncrypter(rsa.RSAPublicKey? publicKey, rsa.RSAPrivateKey? privateKey) {
    return Encrypter(RSA(publicKey: publicKey, privateKey: privateKey));
  }

  static Future<String> decryptParts(List<String> parts, Encrypter encrypter) async {
    String total = await EncryptText.getRSAEncrypter().decrypt(parts, encrypter);
    return total;
  }

  static Future<List<String>> toEncryptedPieces(String message, Encrypter encrypter) async {
    List<String> encryptedParts = await EncryptText.getRSAEncrypter().encrypt(message, encrypter);
    return encryptedParts;
  }
}
