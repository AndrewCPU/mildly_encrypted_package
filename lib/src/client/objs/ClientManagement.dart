import 'package:mildly_encrypted_package/mildly_encrypted_package.dart';
import 'package:mildly_encrypted_package/src/client/data/client_key_manager.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientGroupChat.dart';
import 'package:mildly_encrypted_package/src/client/objs/ServerObject.dart';

import 'ClientUser.dart';

class ClientManagement {
  static final ClientManagement _instance = ClientManagement._internal();

  static Future<ClientManagement> getInstance() async {
    if (!_instance.initialized) {
      await _instance._init();
    }
    return _instance;
  }

  ClientManagement._internal();

  List<ClientUser> _userChats = [];
  List<ClientGroupChat> _groupChats = [];
  bool initialized = false;
  Future<void> _init() async {
    initialized = true;
    _userChats.clear();
    _groupChats.clear();
    EncryptedClient client = EncryptedClient.getInstance()!;
    String serverIP = client.serverUrl;
    Map<String, List<String>> allUuids = await ClientKeyManager().getAllContactUUIDs(serverIP);
    List<String> users = allUuids['users']!;
    List<String> groups = allUuids['groups']!;
    for (String uuid in users) {
      if (uuid == 'server') continue;
      if (uuid == client.uuid) continue;
      _userChats.add((await ClientUser.loadUser(client, uuid))!);
    }
    for (String uuid in groups) {
      if (uuid == 'server') continue;
      if (uuid == client.uuid) continue;

      _groupChats.add((await ClientGroupChat.loadUser(client, uuid))!);
    }
  }

  Future<void> updateChats() async {
    List<ClientUser> _userChats = [];
    List<ClientGroupChat> _groupChats = [];
    EncryptedClient client = EncryptedClient.getInstance()!;
    String serverIP = client.serverUrl;
    Map<String, List<String>> allUuids = await ClientKeyManager().getAllContactUUIDs(serverIP);
    List<String> users = allUuids['users']!;
    List<String> groups = allUuids['groups']!;
    for (String uuid in users) {
      if (uuid == 'server') continue;
      if (uuid == client.uuid) continue;

      _userChats.add((await ClientUser.loadUser(client, uuid))!);
    }
    for (String uuid in groups) {
      if (uuid == 'server') continue;
      if (uuid == client.uuid) continue;
      _groupChats.add((await ClientGroupChat.loadUser(client, uuid))!);
    }
    this._userChats = _userChats;
    this._groupChats = _groupChats;
  }

  List<ClientUser> getAllUsers() {
    return List.from(_userChats)..addAll(_groupChats);
  }

  List<ClientUser> getCommunicableUsers() {
    List<ClientUser> allUsers = List.from(getAllUsers());
    List<ClientUser> cannotCommunicate = [];
    for (ClientUser u in allUsers) {
      if (u.privateKey == null) {
        cannotCommunicate.add(u);
      }
    }
    allUsers.removeWhere((element) => cannotCommunicate.contains(element));
    return allUsers;
  }

  Future<ClientUser?> getUser(String uuid) async {
    for (ClientUser user in _userChats) {
      if (user.uuid == uuid) {
        return user;
      }
    }
    ClientUser? user = await ClientUser.loadUser(EncryptedClient.getInstance()!, uuid);
    if (user != null) {
      _userChats.add(user);
    }
    return user;
  }

  Future<ClientGroupChat?> getGroupChat(String uuid) async {
    for (ClientGroupChat user in _groupChats) {
      if (user.uuid == uuid) {
        return user;
      }
    }
    ClientGroupChat? user = await ClientGroupChat.loadUser(EncryptedClient.getInstance()!, uuid);
    if (user != null) {
      _groupChats.add(user);
    }
    return user;
  }

  Future<ClientUser?> getFromUUID(String uuid) async {
    if (await ClientKeyManager().isGroupChat(EncryptedClient.getInstance()!.serverUrl, uuid)) {
      return await getGroupChat(uuid);
    }
    return await getUser(uuid);
  }

  // Future<void> addUserContact(String uuid) async {
  //   EncryptedClient client = EncryptedClient.getInstance()!;
  //   ServerObject object = await ServerObject.getInstance(client);
  //   // await object.exchangeKeys(uuid);
  // }

  Future<void> deleteGroupChat(ClientGroupChat chat) async {
    _groupChats.remove(chat);
    await ClientKeyManager().deleteContact(chat.client.serverUrl, chat.uuid);
  }

  Future<void> deleteUserChat(ClientUser chat) async {
    _userChats.remove(chat);
    await ClientKeyManager().deleteContact(chat.client.serverUrl, chat.uuid);
  }
}
