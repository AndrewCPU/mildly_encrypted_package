import 'package:mildly_encrypted_package/mildly_encrypted_package.dart';
import 'package:mildly_encrypted_package/src/client/data/client_key_manager.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientGroupChat.dart';
import 'package:mildly_encrypted_package/src/client/objs/ServerObject.dart';

import 'ClientUser.dart';

class ClientManagement {
  static final ClientManagement _instance = ClientManagement._internal();
  ClientManagement._internal();
  static ClientManagement getInstance() {
    return _instance;
  }

  final List<ClientUser> userChats = [];
  final List<ClientGroupChat> groupChats = [];

  Future<void> init() async {
    userChats.clear();
    groupChats.clear();
    EncryptedClient client = EncryptedClient.getInstance()!;
    String serverIP = client.serverUrl;
    Map<String, List<String>> allUuids = await ClientKeyManager().getAllContactUUIDs(serverIP);
    List<String> users = allUuids['users']!;
    List<String> groups = allUuids['groups']!;
    for (String uuid in users) {
      if (uuid == 'server') continue;
      userChats.add((await ClientUser.loadUser(client, uuid))!);
    }
    for (String uuid in groups) {
      if (uuid == 'server') continue;
      groupChats.add((await ClientGroupChat.loadUser(client, uuid))!);
    }
  }

  Future<List<ClientUser>> getAllUsers() async {
    return List.from(userChats)..addAll(groupChats);
  }

  Future<ClientUser?> getUser(String uuid) async {
    for (ClientUser user in userChats) {
      if (user.uuid == uuid) {
        return user;
      }
    }
    ClientUser? user = await ClientUser.loadUser(EncryptedClient.getInstance()!, uuid);
    if (user != null) {
      userChats.add(user);
    }
    return user;
  }

  Future<ClientGroupChat?> getGroupChat(String uuid) async {
    for (ClientGroupChat user in groupChats) {
      if (user.uuid == uuid) {
        return user;
      }
    }
    ClientGroupChat? user = await ClientGroupChat.loadUser(EncryptedClient.getInstance()!, uuid);
    if (user != null) {
      groupChats.add(user);
    }
    return user;
  }

  Future<ClientUser?> getFromUUID(String uuid) async {
    if (await ClientKeyManager().isGroupChat(EncryptedClient.getInstance()!.serverUrl, uuid)) {
      return await getGroupChat(uuid);
    }
    return await getUser(uuid);
  }

  Future<void> addUserContact(String uuid) async {
    EncryptedClient client = EncryptedClient.getInstance()!;
    ServerObject object = await ServerObject.getInstance(client);
    await object.exchangeKeys(uuid);
  }

  Future<void> deleteGroupChat(ClientGroupChat chat) async {
    groupChats.remove(chat);
    await ClientKeyManager().deleteContact(chat.client.serverUrl, chat.uuid);
  }

  Future<void> deleteUserChat(ClientUser chat) async {
    userChats.remove(chat);
    await ClientKeyManager().deleteContact(chat.client.serverUrl, chat.uuid);
  }
}
