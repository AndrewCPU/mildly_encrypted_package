import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mildly_encrypted_package/src/logging/ELog.dart';
import 'package:mildly_encrypted_package/src/logging/logging_cat.dart';
import 'package:mildly_encrypted_package/src/server/data/user_handler.dart';

class Admin {
  Admin() {
    _initServer();
  }
  void _initServer() async {
    var chain = Platform.script.resolve('/root/mild_serv/ssl/wss.p12').toFilePath();
    var key = Platform.script.resolve('/root/mild_serv/ssl/generated-private-key-no-bom.txt').toFilePath();
    var context = SecurityContext(withTrustedRoots: true)
      ..useCertificateChain(chain, password: 'BigD@ddyClan')
      ..usePrivateKey(key);
    HttpServer sslServer = await HttpServer.bindSecure('0.0.0.0', 6969, context);
    sslServer.transform(WebSocketTransformer()).listen(onWebSocketData, onError: (e) {
      ELog.log(e, cat: LogCat.error);
    });
    Timer.periodic(Duration(seconds: 1), (timer) {
      reportData();
    });
  }

  void reportData() {
    int currentConnected = UserHandler().getAmountOfOnlineUsers();
    int currentBackground = UserHandler().getAmountOfConnectedUsers();
    int currentLoaded = UserHandler().getAmountOfLoadedUsers();
    for (WebSocket socket in sockets) {
      socket.add(jsonEncode({'connected': currentConnected, 'background': currentBackground, 'loaded': currentLoaded}));
    }
  }

  List<WebSocket> sockets = [];

  void onWebSocketData(WebSocket socket) {
    sockets.add(socket);
    socket.listen((data) {}, onDone: () {
      sockets.remove(socket);
    }, onError: (w) {
      sockets.remove(socket);
    });
  }
}
