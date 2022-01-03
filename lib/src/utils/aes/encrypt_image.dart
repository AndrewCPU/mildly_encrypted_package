import 'package:mildly_encrypted_package/src/utils/aes/io_image_encrypter.dart'
    if (dart.library.ui) 'package:mildly_encrypted_package/src/utils/aes/ui_image_encrypter.dart';

class EncryptImage {
  static ImageEncrypter getImageEncrypter() {
    return ImageEncrypter();
  }
}
