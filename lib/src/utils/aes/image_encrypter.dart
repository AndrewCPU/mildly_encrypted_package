import 'package:mildly_encrypted_package/src/client/objs/ClientUser.dart';

abstract class ImageEncrypterMod{
  Future<String> encryptImage(String filePath, ClientUser clientUser, int mult, String targetDirectory);
  Future<String> decryptImageToPath(String filePath, ClientUser clientUser, int mult, String targetDirectory);
}