library mildly_encrypted_package;

import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:mildly_encrypted_package/mildly_encrypted_package.dart';
import 'package:mildly_encrypted_package/src/client/data/client_key_manager.dart';
import 'package:mildly_encrypted_package/src/client/data/message_storage.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/message_handler.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientManagement.dart';
import 'package:mildly_encrypted_package/src/client/objs/ServerObject.dart';
import 'package:mildly_encrypted_package/src/utils/GetPath.dart';
import 'package:mildly_encrypted_package/src/utils/save_file.dart';
import 'package:web_socket_channel/io.dart';

import '../logging/ELog.dart';
import 'handlers/web_socket_message_handler.dart';

class EncryptedClient {
  static EncryptedClient? _instance;

  static EncryptedClient? getInstance() {
    return _instance;
  }

  String serverUrl;
  String pushToken;

  void Function(EncryptedClient) onConnect;
  void Function(String, String, String, String)? notificationCallback;
  void Function() receiveSpecialData;

  List<String> offlineQueue = [];

  IOWebSocketChannel? _channel;
  WebSocketDataHandler? _handler;
  String? uuid;
  String rootDirectory;

  bool _authenticated = false;
  bool reset;

  Duration? timeout;
  int lastReceived = 0;

  EncryptedClient(
      {required this.serverUrl,
      required this.pushToken,
      required this.rootDirectory,
      required this.onConnect,
      this.reset = false,
      this.timeout,
      this.notificationCallback,
      required this.receiveSpecialData}) {
    GetPath.initialize(rootDirectory);
    if (_instance != null) {
      _instance!.getChannel()?.sink.close(1234);
      backgroundTimer?.cancel();
    }
    _instance = this;
  }

  bool isAuthenticated() {
    return _authenticated;
  }

  String _myProfilePicturePath = "";
  String _myUsername = "";
  String _myStatus = '';

  bool isConnected() {
    if (getChannel() == null) {
      _authenticated = false;

      return false;
    } else if (getChannel()!.closeCode != null) {
      _authenticated = false;

      return false;
    }
    return true;
  }

  Timer? backgroundTimer;
  void finishedAuthentication() async {
    () async {
      await getServerObject();
      _authenticated = true;
      onConnect(this);
      lastReceived = DateTime.now().millisecondsSinceEpoch;
      if (timeout != null) {
        backgroundTimer = Timer.periodic(timeout!, (timer) {
          if (DateTime.now().millisecondsSinceEpoch - timeout!.inMilliseconds > lastReceived) {
            timer.cancel();
            disconnect();
          }
        });
      }
      for (String s in offlineQueue) {
        (await getServerObject()).sendMessage(s);
      }
      offlineQueue.clear();
    }.call();
  }

  ServerObject? _serverObject;

  Future<void> connect() async {
    _authenticated = false;
    if (_channel != null && _channel!.closeCode == null) {
      _channel?.sink.close(9856, 'Reconnect');
    }
    if (reset) {
      await (await SaveFile.getInstance(path: GetPath.getInstance().path + "/data.json")).clear();
      await ClientKeyManager().reset();
    }
    SaveFile _save = await SaveFile.getInstance(path: GetPath.getInstance().path + "/data.json");
    _myProfilePicturePath = await _save.getString('profile_path') ?? 'null';
    _myUsername = await _save.getString('username') ?? 'Username';
    _myStatus = await _save.getString('status') ?? '';
    await ClientKeyManager().init();
    await MessageStorage().init();
    (await ClientManagement.getInstance());
    try {
      _channel = IOWebSocketChannel(await WebSocket.connect("wss://$serverUrl:4320"));
    } catch (e, s) {
      print(e);
      ELog.i("Unable to connect WebSocket");
      ELog.e(e);
      print(s);
      _authenticated = false;
      return;
    }

    _handler = WebSocketDataHandler(this);
    _channel!.stream.listen(_handler!.handleData, onDone: () {
      ELog.i("Web socket finished.");
      _authenticated = false;
    }, onError: (e, s) {
      ELog.e("An error with the WebSocket: $e");
      _authenticated = false;
    });
    _handler!.introduce();
    _channel!.innerWebSocket?.pingInterval = const Duration(seconds: 5);
  }

  Future<void> disconnect() async {
    if (isConnected()) {
      _authenticated = false;
      getChannel()?.innerWebSocket?.close(9876);
      ELog.i("Disconnecting from server.");
    }
  }

  Future<void> reconnect() async {
    if (!isConnected()) {
      _authenticated = false;
      ELog.i("Reconnecting to server.");
      await connect();
    }
  }

  Future<void> updateMyUsername(String username) async {
    SaveFile _save = await SaveFile.getInstance(path: GetPath.getInstance().path + "/data.json");
    await _save.setString('username', username);
    _myUsername = username;
    List<ClientUser> allChats = (await ClientManagement.getInstance()).getAllUsers();
    for (ClientUser chat in allChats) {
      chat.sendUsernameUpdate(username);
    }
  }

  Future<void> updateMyProfilePath(String path) async {
    SaveFile _save = await SaveFile.getInstance(path: GetPath.getInstance().path + "/data.json");
    await _save.setString('profile_path', path);
    _myProfilePicturePath = path;
    List<ClientUser> allChats = (await ClientManagement.getInstance()).getAllUsers();
    for (ClientUser chat in allChats) {
      chat.sendProfilePictureUpdate(path);
    }
  }

  Future<void> updateMyStatus(String newStatus) async {
    SaveFile _save = await SaveFile.getInstance(path: GetPath.getInstance().path + "/data.json");
    await _save.setString('status', newStatus);
    _myStatus = newStatus;
    List<ClientUser> allChats = (await ClientManagement.getInstance()).getAllUsers();
    for (ClientUser chat in allChats) {
      chat.sendStatusUpdate(newStatus);
    }
  }

  String getMyProfilePicturePath() {
    return _myProfilePicturePath;
  }

  String getMyUsername() {
    return _myUsername;
  }

  String getMyStatus() {
    return _myStatus;
  }

  Future<ServerObject> getServerObject() async {
    _serverObject ??= await ServerObject.getInstance(this);
    return _serverObject!;
  }

  ClientKeyManager get keyManager {
    return ClientKeyManager();
  }

  MessageStorage get messageHandler {
    return MessageStorage();
  }

  IOWebSocketChannel? getChannel() {
    return _channel;
  }
}
