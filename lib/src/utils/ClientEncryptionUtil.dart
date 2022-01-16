import 'package:mildly_encrypted_package/src/client/objs/ClientUser.dart';
import 'package:mildly_encrypted_package/src/utils/aes/encrypt_image.dart';

class ClientEncryptionUtil {
  static Future<String> encryptFileToPath(String filePath, ClientUser clientUser, int mult, String targetDirectory) async {
    return await EncryptImage.getImageEncrypter().encryptImage(filePath, clientUser, mult, targetDirectory);
  }

  static Future<String> decryptImageToPath(String filePath, ClientUser clientUser, int mult, String targetDirectory) async {
    return await EncryptImage.getImageEncrypter().decryptImageToPath(filePath, clientUser, mult, targetDirectory);
  }
}
