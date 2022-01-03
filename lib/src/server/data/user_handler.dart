import 'dart:io';

import '../../logging/ELog.dart';
import '../../utils/key_type.dart';
import '../user/user.dart';
import 'key_handler.dart';
import 'package:collection/collection.dart';

class UserHandler {
  static final UserHandler _instance = UserHandler._internal();
  factory UserHandler() {
    return _instance;
  }
  UserHandler._internal();

  final List<User> _currentUsers = [];

  User? getUser({String? uuid, WebSocket? socket}) {
    if (uuid != null) {
      return _currentUsers.firstWhereOrNull((e) => e.uuid == uuid);
    }
    if (socket != null) {
      return _currentUsers.firstWhereOrNull((e) => e.activeSocket == socket);
    }
    return null;
  }

  Future<User?> getOrLoadUser(String uuid) async {
    User? user = getUser(uuid: uuid);
    user ??= await loadUser(uuid);
    return user;
  }

  Future<User?> loadUser(String uuid) async {
    if (!(await KeyHandler().doesUserExist(uuid))) {
      return null;
    }
    User user = User(uuid: uuid);
    if (await KeyHandler().hasValidPublicKey(uuid)) {
      user.update(KeyType.public, (await KeyHandler().getRSAPublicKey(uuid))!);
    }
    if (await KeyHandler().hasValidPrivateKey(uuid)) {
      user.update(
          KeyType.private, (await KeyHandler().getRSAPrivateKey(uuid))!);
    }
    User? inList = getUser(uuid: uuid);
    if (inList != null) {
      _currentUsers.remove(inList);
    }
    _currentUsers.add(user);
    return user;
  }

  Future<User?> createUser(String uuid, String publicKey) async {
    if (await KeyHandler().doesUserExist(uuid)) {
      ELog.e("UserID already exists!");
      return null;
    }
    if (await KeyHandler().insertUser(uuid, publicKey)) {
      ELog.i("Was able to insert user!");
      return loadUser(uuid);
    } else {
      ELog.e("???");
      return null;
    }
  }
}
