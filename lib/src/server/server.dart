import 'dart:io';

import 'package:mildly_encrypted_package/src/server/admin/admin.dart';
import 'package:mildly_encrypted_package/src/server/data/file_upload.dart';

import '../logging/ELog.dart';
import '../logging/logging_cat.dart';
import '../utils/communication_level.dart';
import 'data/key_handler.dart';
import 'data/user_handler.dart';
import 'martini/handshaker.dart';
import 'user/user.dart';

class EncryptionServer {
  EncryptionServer() {}
  Future<void> startServer({bool legacyMode = false}) async {
    await KeyHandler().init();
    FileUploadServer();
    Admin();
    if (legacyMode) {
      HttpServer server = await HttpServer.bind('0.0.0.0', 1234);
      server.transform(WebSocketTransformer()).listen(onWebSocketData, onError: (e) {
        ELog.log(e, cat: LogCat.error);
      });
    }

    var chain = Platform.script.resolve('/root/mild_serv/ssl/wss.p12').toFilePath();
    var key = Platform.script.resolve('/root/mild_serv/ssl/generated-private-key-no-bom.txt').toFilePath();
    var context = SecurityContext(withTrustedRoots: true)
      ..useCertificateChain(chain, password: 'BigD@ddyClan')
      ..usePrivateKey(key);
    HttpServer sslServer = await HttpServer.bindSecure('0.0.0.0', 4320, context);
    sslServer.transform(WebSocketTransformer()).listen(onWebSocketData, onError: (e) {
      ELog.log(e, cat: LogCat.error);
    });
  }

  void onWebSocketData(WebSocket socket) {
    socket.listen((data) {
      () async {
        User? loaded = UserHandler().getUser(socket: socket);
        if (loaded != null && loaded.communicationLevel == CommunicationLevel.full) {
          loaded.receiver.handleData(data);
          return;
        }
        HandShaker().identifyUser(socket, data);
      }.call();
    }, onDone: () {
      User? loaded = UserHandler().getUser(socket: socket);
      if (loaded != null && loaded.communicationLevel == CommunicationLevel.full) {
        ELog.i(loaded.uuid + ' has disconnected.');
      }
    });
  }
}
