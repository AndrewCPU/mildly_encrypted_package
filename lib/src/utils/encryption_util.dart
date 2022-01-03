import 'dart:io';

import 'package:aes_crypt_null_safe/aes_crypt_null_safe.dart';
import 'package:encrypt/encrypt.dart';
import 'package:mildly_encrypted_package/src/client/data/client_key_manager.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientUser.dart';
import 'package:mildly_encrypted_package/src/utils/aes/encrypt_image.dart';
import 'package:pointycastle/asymmetric/api.dart' as rsa;
import 'package:pointycastle/api.dart' as asym;

import '../logging/ELog.dart';
import 'crypto_utils.dart';
import 'key_type.dart';
import 'magic_nums.dart';
import 'string_util.dart';

class EncryptionUtil {
  static Future<String> encryptFileToPath(String filePath, ClientUser clientUser, String targetDirectory) async {
    return await EncryptImage.getImageEncrypter().encryptImage(filePath, clientUser, targetDirectory);
  }

  static Future<String> decryptImageToPath(String filePath, ClientUser clientUser, String targetDirectory) async {
    return await EncryptImage.getImageEncrypter().decryptImageToPath(filePath, clientUser, targetDirectory);
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

  static String decryptParts(List<String> parts, Encrypter encrypter) {
    int n = DateTime.now().millisecondsSinceEpoch;
    String total = '';
    for (String part in parts) {
      total += decryptMessage(part, encrypter);
    }
    ELog.i("It took " + ((DateTime.now().millisecondsSinceEpoch - n).toString()) + "ms to decrypt a message.");

    return total;
  }

  static String decryptMessage(String message, Encrypter encrypter) {
    int n = DateTime.now().millisecondsSinceEpoch;
    String s = encrypter.decrypt64(message);
    return s;
  }

  static String encrypt(String message, Encrypter encrypter) {
    if (message.length > MagicNumber.ENCRYPTION_MESSAGE_SIZE) {
      ELog.e("Message size overflow when attempting to encrypt $message.");
      return "Error";
    }
    return encrypter.encrypt(message).base64;
  }

  static List<String> toEncryptedPieces(String message, Encrypter encrypter) {
    int n = DateTime.now().millisecondsSinceEpoch;

    List<String> parts = StringUtils.breakToPieces(message, MagicNumber.ENCRYPTION_MESSAGE_SIZE);
    List<String> encryptedParts = parts.map((part) => encrypt(part, encrypter)).toList();
    ELog.i("It took " + ((DateTime.now().millisecondsSinceEpoch - n).toString()) + "ms to encrypt a message.");

    return encryptedParts;
  }
}
