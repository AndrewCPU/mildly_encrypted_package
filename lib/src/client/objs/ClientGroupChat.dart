import 'dart:convert';
import 'dart:io';

import 'package:encrypt/encrypt.dart';
import 'package:mildly_encrypted_package/mildly_encrypted_package.dart';
import 'package:mildly_encrypted_package/src/client/cutil/client_components.dart';
import 'package:mildly_encrypted_package/src/client/cutil/notification_registry.dart';
import 'package:mildly_encrypted_package/src/client/data/client_key_manager.dart';
import 'package:mildly_encrypted_package/src/client/data/message_storage.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientManagement.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientUser.dart';
import 'package:mildly_encrypted_package/src/client/objs/encryption_pack.dart';
import 'package:mildly_encrypted_package/src/logging/ELog.dart';
import 'package:mildly_encrypted_package/src/utils/GetPath.dart';
import 'package:mildly_encrypted_package/src/utils/aes/file_download.dart';
import 'package:mildly_encrypted_package/src/utils/crypto_utils.dart';
import 'package:mildly_encrypted_package/src/utils/encryption_util.dart';
import 'package:mildly_encrypted_package/src/utils/magic_nums.dart';

import 'package:pointycastle/asymmetric/api.dart' as rsa;
import 'package:pointycastle/api.dart' as asym;
import 'package:uuid/uuid.dart';

import 'ServerObject.dart';

class ClientGroupChat extends ClientUser {
  static Future<ClientGroupChat?> loadUser(EncryptedClient client, String keyID) async {
    ClientKeyManager keyManager = ClientKeyManager();
    if (!(await keyManager.doesContactExist(client.serverUrl, keyID))) {
      ELog.e("Group does not exist. Cannot be loaded ($keyID)");
      return null;
    }

    Map? data = await ClientKeyManager().getUserData(client.serverUrl, keyID);

    ClientGroupChat chat = ClientGroupChat.internal(keyID, client, ((data!['members']) as List).cast<String>());

    await chat.init();
    return chat;
  }

  static Future<ClientGroupChat> createGroupChat(List<String> members, String groupChatName) async {
    List<int> seeds = CryptoUtils.getSecureRandomSeeds();
    asym.AsymmetricKeyPair keyPair = CryptoUtils.generateRSAKeyPair(seeds: seeds);
    String publicKeyString = CryptoUtils.encodeRSAPublicKeyToPem(keyPair.publicKey as rsa.RSAPublicKey);
    String privateKeyString = CryptoUtils.encodeRSAPrivateKeyToPem(keyPair.privateKey as rsa.RSAPrivateKey);
    EncryptedClient client = EncryptedClient.getInstance()!;
    members.add(client.uuid!);
    String uuid = Uuid().v4();
    await ClientKeyManager().createContact(client.serverUrl, uuid,
        publicKey: publicKeyString,
        privateKey: privateKeyString,
        remotePublic: publicKeyString,
        randInt: privateKeyString.hashCode,
        remoteRandInt: publicKeyString.hashCode,
        data: {'members': members, 'seeds': seeds});
    ClientGroupChat groupChat = (await ClientManagement.getInstance().getGroupChat(uuid))!;
    await groupChat.init();
    await groupChat.updateUsername(groupChatName);

    Map message = {
      ClientComponent.SEED_INFORMATION: seeds,
      ClientComponent.GROUP_NAME: groupChatName,
      ClientComponent.GROUP_MEMBERS: members,
      ClientComponent.GROUP_UUID: uuid
    };

    for (String member in members) {
      if (member == client.uuid!) {
        continue;
      }
      ClientUser? user = ((await ClientManagement.getInstance().getUser(member)));
      if (user == null) {
        ELog.e("Unable to add $member to Group $uuid.");
        continue;
      }
      await user.sendDataPacket(jsonEncode(message));
    }

    return groupChat;
  }

  List<String> members;
  ClientGroupChat.internal(uuid, client, this.members) : super.internal(uuid, client);

  Future<void> leaveGroupChat() async {
    Map message = {ClientComponent.LEAVE_GROUP: DateTime.now().millisecondsSinceEpoch};
    await sendDataPacket(jsonEncode(message));
    //todo delete group chat
  }

  Future<void> inviteToChat(String uuid) async {
    List<int> seeds = (await ClientKeyManager().getGroupChatSeeds(client.serverUrl, this.uuid))!;
    Map messageToNewUser = {
      ClientComponent.SEED_INFORMATION: seeds,
      ClientComponent.GROUP_NAME: username,
      ClientComponent.GROUP_MEMBERS: [uuid, ...members],
      ClientComponent.GROUP_UUID: this.uuid
    };
    ClientUser user = ((await ClientManagement.getInstance().getUser(uuid)))!;

    await user.sendDataPacket(jsonEncode(messageToNewUser));
    await sendDataPacket(jsonEncode({ClientComponent.ADD_TO_GROUP: uuid}));
    members.add(uuid);
    await ClientKeyManager().setGroupChatMembers(client.serverUrl, this.uuid, members);
  }

  Future<void> sendGroupNameUpdate(String newGroupName) async {
    Map map = {ClientComponent.NAME_UPDATE: newGroupName};
    await sendDataPacket(jsonEncode(map));
    await updateUsername(newGroupName);
    UpdateNotificationRegistry.getInstance().newName(this, newGroupName);
  }

  Future<void> sendGroupImageUpdate(String newGroupImageLocalPath) async {
    Directory directory = Directory(GetPath.getInstance().path + Platform.pathSeparator + uuid + Platform.pathSeparator);
    String encryptFile = await EncryptionUtil.encryptFileToPath(newGroupImageLocalPath, this, directory.path);
    String? uploadedPath = await FileDownload.uploadFile(encryptFile);
    if (uploadedPath == null) {
      ELog.e("Something went wrong with a file upload! to $uuid");
      return;
    }
    String newLocalCopy =
        directory.path + Platform.pathSeparator + newGroupImageLocalPath.substring(newGroupImageLocalPath.lastIndexOf(Platform.pathSeparator) + 1);
    await File(newGroupImageLocalPath).copy(newLocalCopy);
    await sendDataPacket(jsonEncode({ClientComponent.GROUP_IMAGE_UPDATE: uploadedPath}));
    await updateProfilePicturePath(newLocalCopy);
    UpdateNotificationRegistry.getInstance().newPicture(this, newLocalCopy);
  }

  @override
  Future<void> sendDataPacket(String message) async {
    List<String> encryptedBlocks = EncryptionUtil.toEncryptedPieces(message, encrypter);
    Map send = {
      MagicNumber.MESSAGE_COMPILATION: encryptedBlocks,
      MagicNumber.TO_USER: List.from(members)..remove(client.uuid!),
      MagicNumber.KEY_ID: uuid,
    };
    String toSendJson = jsonEncode(send);
    ServerObject obj = await ServerObject.getInstance(client);
    await obj.sendMessage(toSendJson);
  }

  Future<bool> isAnyoneTyping() async {
    Map? data = await ClientKeyManager().getUserData(client.serverUrl, uuid);
    if (data == null) {
      ELog.e("Cannot check if the user is typing, cannot locate user data in table for " + (uuid));
      return false;
    }
    if (!data.containsKey('typing')) {
      ELog.e('Cannot find typing data in user data for ' + (uuid));
      return false;
    }
    Map typing = data['typing']!;
    if (!typing.containsKey(uuid)) {
      ELog.e('User has not typed before therefore they are not typing. ' + (uuid));
      return false;
    }
    for(String key in typing.keys){
        if(DateTime.now().millisecondsSinceEpoch < typing[key] + MagicNumber.TYPING_TIMEOUT_IN_MS){
          return true;
        }
    }
    return false;
  }

  @override
  Future<void> init() async {
    super.init();
    members = (await ClientKeyManager().getGroupChatMembers(client.serverUrl, uuid))!;
  }
}
