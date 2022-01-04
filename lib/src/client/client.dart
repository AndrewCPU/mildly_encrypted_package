library mildly_encrypted_package;

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
  void Function() receiveSpecialData;

  IOWebSocketChannel? _channel;
  WebSocketDataHandler? _handler;
  String? uuid;
  String rootDirectory;

  bool _authenticated = false;
  bool reset;
  EncryptedClient(
      {required this.serverUrl,
      required this.pushToken,
      required this.rootDirectory,
      required this.onConnect,
      this.reset = false,
      required this.receiveSpecialData}) {
    GetPath.initialize(rootDirectory);
    _instance = this;
  }

  bool isAuthenticated() {
    return _authenticated;
  }

  String _myProfilePicturePath = "";
  String _myUsername = "";

  bool isConnected() {
    if (getChannel() == null) {
      return false;
    } else if (getChannel()!.closeCode != null) {
      return false;
    }
    return true;
  }

  Future<void> updateMyUsername(String username) async {
    SaveFile _save = await SaveFile.getInstance(path: GetPath.getInstance().path + "/data.json");
    await _save.setString('username', username);
    _myUsername = username;
    List<ClientUser> allChats = await (await ClientManagement.getInstance()).getAllUsers();
    for (ClientUser chat in allChats) {
      await chat.sendUsernameUpdate(username);
    }
    //todo send packet out
  }

  Future<void> updateMyProfilePath(String path) async {
    SaveFile _save = await SaveFile.getInstance(path: GetPath.getInstance().path + "/data.json");
    await _save.setString('profile_path', path);
    _myProfilePicturePath = path;
    //todo send packet out
  }

  String getMyProfilePicturePath() {
    return _myProfilePicturePath;
  }

  String getMyUsername() {
    return _myUsername;
  }

  void finishedAuthentication() {
    () async {
      await MessageStorage().init();
      (await ClientManagement.getInstance());
      _authenticated = true;
      onConnect(this);
    }.call();
  }

  Future<void> connect() async {
    if (reset) {
      await (await SaveFile.getInstance(path: GetPath.getInstance().path + "/data.json")).clear();
      await ClientKeyManager().reset();
    }
    SaveFile _save = await SaveFile.getInstance(path: GetPath.getInstance().path + "/data.json");
    _myProfilePicturePath = await _save.getString('profile_path') ?? 'null';
    _myUsername = await _save.getString('username') ?? 'Username';
    try {
      _channel = IOWebSocketChannel(await WebSocket.connect("ws://$serverUrl:1234"));
    } catch (e, s) {
      ELog.i("Unable to connect WebSocket");
      ELog.e(e);
      ELog.e(s);
      return;
    }

    _handler = WebSocketDataHandler(this);
    _channel!.stream.listen(_handler!.handleData, onDone: () {
      ELog.i("Web socket finished.");
    }, onError: (e, s) {
      ELog.e("An error with the WebSocket: $e");
    });
    _handler!.introduce();
    _channel!.innerWebSocket?.pingInterval = const Duration(seconds: 5);
  }

  Future<ServerObject> getServerObject() async {
    return await ServerObject.getInstance(this);
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
