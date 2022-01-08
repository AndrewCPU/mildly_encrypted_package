import 'package:encrypt/encrypt.dart';
import 'package:mildly_encrypted_package/mildly_encrypted_package.dart';

abstract class EncryptRSA{
  Future<List<String>> encrypt(String message, Encrypter encrypter);
  Future<String> decrypt(List<String> message, Encrypter encrypter);
}