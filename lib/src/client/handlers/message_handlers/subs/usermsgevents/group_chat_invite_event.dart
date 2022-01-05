import 'dart:convert';

import 'package:mildly_encrypted_package/mildly_encrypted_package.dart';
import 'package:mildly_encrypted_package/src/client/cutil/client_components.dart';
import 'package:mildly_encrypted_package/src/client/data/client_key_manager.dart';
import 'package:mildly_encrypted_package/src/client/handlers/message_handlers/message_handler.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientGroupChat.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientManagement.dart';
import 'package:mildly_encrypted_package/src/logging/ELog.dart';
import 'package:mildly_encrypted_package/src/utils/crypto_utils.dart';
import 'package:mildly_encrypted_package/src/utils/json_validator.dart';
import 'package:uuid/uuid.dart';
import 'package:pointycastle/asymmetric/api.dart' as rsa;
import 'package:pointycastle/api.dart' as asym;

class GroupChatInviteEvent implements MessageHandler {
  @override
  bool check(String message, String from, {String? keyID}) {
    return (JSONValidate.isValidJSON(message,
        requiredKeys: [ClientComponent.GROUP_MEMBERS, ClientComponent.GROUP_NAME, ClientComponent.GROUP_UUID, ClientComponent.SEED_INFORMATION]));
  }

  @override
  String getHandlerName() {
    return 'Group Chat Handler';
  }

  Future<void> createGroupChat(List<int> seeds, List<String> members, String groupChatName, String groupUuid) async {
    asym.AsymmetricKeyPair keyPair = CryptoUtils.generateRSAKeyPair(seeds: seeds);
    String publicKeyString = CryptoUtils.encodeRSAPublicKeyToPem(keyPair.publicKey as rsa.RSAPublicKey);
    String privateKeyString = CryptoUtils.encodeRSAPrivateKeyToPem(keyPair.privateKey as rsa.RSAPrivateKey);

    EncryptedClient client = EncryptedClient.getInstance()!;

    for (String member in members) {
      if (!(await ClientKeyManager().doesContactExist(client.serverUrl, member))) {
        await ClientKeyManager().createContact(
          client.serverUrl,
          member,
        );
      }
    }

    await ClientKeyManager().createContact(client.serverUrl, groupUuid,
        publicKey: publicKeyString,
        privateKey: privateKeyString,
        remotePublic: publicKeyString,
        randInt: privateKeyString.hashCode,
        remoteRandInt: publicKeyString.hashCode,
        data: {'members': members, 'seeds': seeds});
    ClientGroupChat groupChat = ((await (await ClientManagement.getInstance()).getGroupChat(groupUuid))!);

    await groupChat.init();
    await groupChat.updateUsername(groupChatName);
    (await (await ClientManagement.getInstance()).updateChats());
    CoreEventRegistry().notify(CoreEventType.KEY_EXCHANGE_COMPLETE, data: groupUuid);
  }

  @override
  Future<void> handle(String message, String from, {String? keyID}) async {
    ELog.i(message);
    Map map = jsonDecode(message);
    List<String> members = ((map[ClientComponent.GROUP_MEMBERS] as List).cast<String>());
    List<int> seeds = ((map[ClientComponent.SEED_INFORMATION] as List).cast<int>());
    String groupName = map[ClientComponent.GROUP_NAME];
    String uuidOfGroup = map[ClientComponent.GROUP_UUID];
    await createGroupChat(seeds, members, groupName, uuidOfGroup);
  }
}
