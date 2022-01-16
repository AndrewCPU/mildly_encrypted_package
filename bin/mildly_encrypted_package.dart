import 'package:mildly_encrypted_package/src/server/server.dart';

// import 'package:mildly_encrypted_package/src/utils/encryption_util.dart';

void main() async {
  // EncryptionUtil
  EncryptionServer server = EncryptionServer();
  await server.startServer();
}
