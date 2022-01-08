import 'package:encrypt/encrypt.dart';
import 'package:mildly_encrypted_package/src/utils/magic_nums.dart';
import 'package:mildly_encrypted_package/src/utils/rsa/rsa_encrypter.dart';
import 'package:mildly_encrypted_package/src/utils/string_util.dart';

class RSAEncrypter implements EncryptRSA {
  @override
  Future<String> decrypt(List<String> messages, Encrypter encrypter) async {
    String total = '';
    for (String m in messages) {
      total += encrypter.decrypt64(m);
    }
    return total;
  }

  @override
  Future<List<String>> encrypt(String messageString, Encrypter encrypter) async {
    List<String> message = StringUtils.breakToPieces(messageString, MagicNumber.ENCRYPTION_MESSAGE_SIZE);
    List<String> total = [];
    for (String m in message) {
      total.add(encrypter.encrypt(m).base64);
    }
    return total;
  }
}
