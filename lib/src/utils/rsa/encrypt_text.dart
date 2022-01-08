import 'package:mildly_encrypted_package/src/utils/rsa/rsa_encrypter.dart';
import 'package:mildly_encrypted_package/src/utils/rsa/io_rsa_encrypter.dart'
  if (dart.library.ui) 'package:mildly_encrypted_package/src/utils/rsa/ui_rsa_encrypter.dart';


class EncryptText {
  static EncryptRSA getRSAEncrypter() {
    return RSAEncrypter();
  }
}
