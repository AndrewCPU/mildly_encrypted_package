import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/server_message_handler.dart';
import 'package:mildly_encrypted_package/src/client/objs/ServerObject.dart';
import 'package:mildly_encrypted_package/src/utils/json_validator.dart';
import 'package:mildly_encrypted_package/src/utils/magic_nums.dart';

import '../client.dart';
import 'handshake_handler.dart';

class WebSocketDataHandler {
  EncryptedClient client;
  ServerObject? serverObject;
  ServerMessageHandler? serverMessageHandler;

  WebSocketDataHandler(this.client);

  void introduce() {
    HandshakeHandler().handleHandshake(client.getChannel()!, client);
  }

  void handleData(dynamic data) {
    client.lastReceived = DateTime.now().millisecondsSinceEpoch;
    if (!client.isAuthenticated()) {
      HandshakeHandler().handleHandshake(client.getChannel()!, client, data: data);
      return;
    } else {
      if (JSONValidate.isValidJSON(data, requiredKeys: [MagicNumber.STATUS])) {
        client.deauthenticate();
        HandshakeHandler().handleHandshake(client.getChannel()!, client, data: data);
        return;
      }
      () async {
        serverObject ??= await ServerObject.getInstance(client);
        serverMessageHandler ??= ServerMessageHandler(serverObject!);
        serverMessageHandler!.handle(client, data);
      }.call();
    }
  }
}
