import 'package:encrypt/encrypt.dart';
import 'package:flutter/foundation.dart';
import 'package:mildly_encrypted_package/src/utils/crypto_utils.dart';
import 'package:mildly_encrypted_package/src/utils/magic_nums.dart';
import 'package:mildly_encrypted_package/src/utils/rsa/rsa_encrypter.dart';
import 'package:mildly_encrypted_package/src/utils/string_util.dart';
import 'package:pointycastle/asymmetric/api.dart' as rsa;

String _decrypt(List<String> list) {
  String private_key = list[0];
  List<String> message = list.sublist(1);
  Encrypter encrypter = Encrypter(RSA(privateKey: CryptoUtils.rsaPrivateKeyFromPem(private_key)));
  String total = '';
  for (String m in message) {
    total += encrypter.decrypt64(m);
  }
  return total;
}

List<String> _encrypt(List<String> list) {
  String public_key = list[0];
  String messageString = list[1];
  Encrypter encrypter = Encrypter(RSA(publicKey: CryptoUtils.rsaPublicKeyFromPem(public_key)));
  List<String> message = StringUtils.breakToPieces(messageString, MagicNumber.ENCRYPTION_MESSAGE_SIZE);
  List<String> total = [];
  for (String m in message) {
    total.add(encrypter.encrypt(m).base64);
  }
  return total;
}

class RSAEncrypter implements EncryptRSA {
  @override
  Future<String> decrypt(List<String> messages, Encrypter encrypter) async {
    String answer = await compute(_decrypt, [CryptoUtils.encodeRSAPrivateKeyToPem(((encrypter.algo) as RSA).privateKey! as rsa.RSAPrivateKey), ...messages]);
    return answer;
  }

  @override
  Future<List<String>> encrypt(String message, Encrypter encrypter) async {
    List<String> answer = await compute(_encrypt, [CryptoUtils.encodeRSAPublicKeyToPem(((encrypter.algo) as RSA).publicKey! as rsa.RSAPublicKey), message]);
    return answer;
  }
}
