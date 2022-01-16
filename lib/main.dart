// import 'dart:async';
// import 'dart:convert';
// import 'dart:math';
//
// import 'package:mildly_encrypted_package/mildly_encrypted_package.dart';
// import 'package:mildly_encrypted_package/src/client/objs/ClientGroupChat.dart';
// import 'package:mildly_encrypted_package/src/client/objs/ClientUser.dart';
// import 'package:mildly_encrypted_package/src/client/objs/ServerObject.dart';
// import 'package:mildly_encrypted_package/src/server/server.dart';
// import 'package:mildly_encrypted_package/src/server/user/user.dart';
//
// void main(args) async {
//   print(args);
//   if (args.isNotEmpty) {
//     if (args[0] == 'client') {
//       // String phoneUUID = 'd34f9b6b-b102-4a27-86cc-3c0f1bb13966';
//       // String messageID = 'bcd28373-e757-4d24-bfe5-479df2d837f6';
//       String cellPhone = '9256cd40-51ea-4b81-9ebd-06907c88c2de';
//       EncryptedClient client = EncryptedClient(
//           serverUrl: 'dialchat.app',
//           pushToken: 'push',
//           reset: false,
//           rootDirectory: 'C:\\Users\\stein\\Documents\\GitHub\\mildly_encrypted_package\\databases\\',
//           onConnect: (client) async {
//             print(client.uuid!);
//             // Timer(Duration(seconds: 3), () async {
//             //   ClientGroupChat group = (await ((await ClientManagement.getInstance()).getGroupChat('32345548-6a23-4824-9c31-180feade5557')))!;
//             //   group.sendChatMessage('yoyoyo');
//             // });
//             // (await client.getServerObject()).exchangeKeys('78615eec-8763-436a-b781-94df0d0b533a');
//           },
//           receiveSpecialData: () {});
//       await client.connect();
//     } else if (args[0] == 'video') {}
//   } else {
//     EncryptionServer server = EncryptionServer();
//     await server.startServer();
//   }
// }
