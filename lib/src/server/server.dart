import 'dart:io';

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

  Future<void> startServer() async {
    await KeyHandler().init();
    FileUploadServer();
    HttpServer server = await HttpServer.bind('0.0.0.0', 1234);
    server.transform(WebSocketTransformer()).listen(onWebSocketData, onError: (e) {
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
    });
  }
}