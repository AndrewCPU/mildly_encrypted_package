import 'package:encrypt/encrypt.dart';

import 'package:mildly_encrypted_package/src/utils/rsa/encrypt_text.dart';
import 'package:pointycastle/asymmetric/api.dart' as rsa;

import 'crypto_utils.dart';
import 'key_type.dart';

class EncryptionUtil {
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
