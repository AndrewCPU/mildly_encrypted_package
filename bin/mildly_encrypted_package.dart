import 'package:mildly_encrypted_package/src/server/server.dart';

void main() async {
  EncryptionServer server = EncryptionServer();
  await server.startServer();
}
