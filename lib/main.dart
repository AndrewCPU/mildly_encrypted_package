import 'package:mildly_encrypted_package/mildly_encrypted_package.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientGroupChat.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientUser.dart';
import 'package:mildly_encrypted_package/src/client/objs/ServerObject.dart';
import 'package:mildly_encrypted_package/src/server/server.dart';
import 'package:mildly_encrypted_package/src/server/user/user.dart';

void main(args) async {
  print(args);
  if (args.isNotEmpty) {
    if (args[0] == 'client') {
      // String phoneUUID = 'd34f9b6b-b102-4a27-86cc-3c0f1bb13966';
      // String messageID = 'bcd28373-e757-4d24-bfe5-479df2d837f6';

      EncryptedClient client = EncryptedClient(
          serverUrl: '127.0.0.1',
          pushToken: 'push',
          reset: false,
          rootDirectory: 'C:\\Users\\stein\\Documents\\GitHub\\mildly_encrypted_package\\databases\\',
          onConnect: (client) async {
            ClientUser? user = await ClientManagement.getInstance().getUser('d0db8614-c1eb-424b-9222-317376fb845e');
            // user!.sendTypingIndicator();
            // await user!.sendUsernameUpdate('Test Computer');
            // await user.sendProfilePictureUpdate(
            //     'C:\\Users\\stein\\Documents\\GitHub\\mildly_encrypted_package\\databases\\d34f9b6b-b102-4a27-86cc-3c0f1bb13966\\WIN_20210309_12_21_02_Pro.jpg');
            user!.sendChatMessage('Hey.');
            // print(ClientManagement.getInstance().userChats);
            // print(client.uuid);
          },
          receiveSpecialData: () {});
      await client.connect();
    }
  } else {
    EncryptionServer server = EncryptionServer();
    await server.startServer();
  }
}
