import 'dart:convert';
import 'dart:io';
import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/asymmetric/api.dart' as rsa;
import 'package:pointycastle/api.dart' as asym;
import '../../logging/ELog.dart';
import '../../utils/communication_level.dart';
import '../../utils/encryption_util.dart';
import '../../utils/key_type.dart';
import '../../utils/magic_nums.dart';
import '../data/key_handler.dart';
import '../firebase/offline_handler.dart';
import 'user_receiver.dart';

class User {
  WebSocket? activeSocket;
  String uuid;
  rsa.RSAPublicKey? userPublic;
  rsa.RSAPrivateKey? ourPrivate;
  late Encrypter encrypter;
  late UserReceiver receiver;
  bool showOnlineStatus = true;
  User({required this.uuid}) {
    receiver = UserReceiver(this);
  }

  void update(KeyType keyType, asym.AsymmetricKey key) {
    switch (keyType) {
      case KeyType.public:
        userPublic = key as rsa.RSAPublicKey;
        break;
      case KeyType.private:
        ourPrivate = key as rsa.RSAPrivateKey;
        break;
    }
    _createEncrypter();
  }

  Future<void> updatePushNotificationCode(String key) async {
    String? data = await KeyHandler().getUserDataColumn(uuid);
    if (data == null) {
      ELog.e("Error fetching data whilst trying to update push notification for $uuid");
      return;
    }
    Map decoded = jsonDecode(data);
    decoded['push'] = key;
    await KeyHandler().updateUserDataColumn(uuid, data: decoded);
  }

  Future<String?> getPushNotificationCode() async {
    String? data = await KeyHandler().getUserDataColumn(uuid);
    if (data == null) {
      ELog.e("Error fetching data whilst trying to get push notification for $uuid");
      return null;
    }
    Map decoded = jsonDecode(data);
    if (decoded.containsKey('push')) {
      return decoded['push']!;
    } else {
      return null;
    }
  }

  Future<void> sendNotification() async {
    if ((await getPushNotificationCode()) == null) {
      ELog.e("Cannot send $uuid a notification! No token!");
      return;
    }
    OfflineHandler().sendNotification(OfflineHandler.bodyBuilder(
        targetToken: (await getPushNotificationCode())!, data: {'message-type': 'new_message', 'time_of': DateTime.now().millisecondsSinceEpoch.toString()}));
  }

  void _createEncrypter() {
    encrypter = EncryptionUtil.createEncrypter(userPublic, ourPrivate);
  }

  Future<String> decryptParts(List<String> parts) async {
    return await EncryptionUtil.decryptParts(parts, encrypter);
  }

  Future<List<String>> getEncryptedPieces(String message) async {
    return await EncryptionUtil.toEncryptedPieces(message, encrypter);
  }

  Future<void> sendMessage(String message) async {
    List<String> encryptedPieces = await getEncryptedPieces(message);
    activeSocket!.add(jsonEncode({MagicNumber.MESSAGE_COMPILATION: encryptedPieces}));
  }

  Future<void> addToCache(String message) async {
    List<String> encryptedPieces = await getEncryptedPieces(message);
    String encryptedMessage = jsonEncode({MagicNumber.MESSAGE_COMPILATION: encryptedPieces});
    String? dataCol = await KeyHandler().getUserDataColumn(uuid);
    if (dataCol == null) {
      ELog.e("Unable to get $uuid data column.");
      return;
    }
    Map<String, dynamic> decoded = jsonDecode(dataCol);
    List<String> cache = [];
    if (decoded.containsKey("cache")) {
      cache = (decoded['cache'] as List).cast<String>();
    }
    cache.add(encryptedMessage);
    decoded['cache'] = cache;
    await KeyHandler().updateUserDataColumn(uuid, data: decoded); // update cache
    await sendNotification();
  }

  Future<void> identified(WebSocket socket) async {
    ELog.i("Identified $uuid");
    activeSocket = socket;
  }

  Future<void> unloadCache() async {
    String? dataCol = await KeyHandler().getUserDataColumn(uuid);
    if (dataCol == null) {
      ELog.e("Unable to get $uuid data column.");
      return;
    }
    Map<String, dynamic> decoded = jsonDecode(dataCol);
    if (decoded.containsKey("cache")) {
      List<String> cache = (decoded['cache'] as List).cast<String>();
      for (String msg in cache) {
        activeSocket!.add(msg);
      }
      decoded['cache'] = [];
      await KeyHandler().updateUserDataColumn(uuid, dataString: jsonEncode(decoded));
      (await KeyHandler().getUserDataColumn(uuid))!.toString();
    }
  }

  bool isOnline() {
    if (activeSocket == null) {
      return false;
    }
    return activeSocket!.closeCode == null && showOnlineStatus;
  }

  bool hasActiveBackgroundConnection() {
    if (activeSocket == null) {
      return false;
    }
    return activeSocket!.closeCode == null;
  }

  CommunicationLevel get communicationLevel {
    // our communication abilities with serv user
    int level = 0;
    if (userPublic != null) {
      level++;
    }
    if (ourPrivate != null) {
      level++;
    }
    if (level == 2) {
      return CommunicationLevel.full;
    }
    if (level == 0) {
      return CommunicationLevel.none;
    }
    if (userPublic != null) {
      return CommunicationLevel.canSend;
    }
    return CommunicationLevel.canRead;
  }
}
