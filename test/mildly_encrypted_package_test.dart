import 'package:mildly_encrypted_package/src/server/server.dart';
import 'package:test/test.dart';

void main() async {
  EncryptionServer server = EncryptionServer();
  await server.startServer();
}
