import 'package:encrypt/encrypt.dart';

abstract class EncryptRSA {
  Future<List<String>> encrypt(String message, Encrypter encrypter);
  Future<String> decrypt(List<String> message, Encrypter encrypter);
}
