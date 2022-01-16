import 'dart:convert';

import '../../logging/ELog.dart';
import '../../utils/encryption_util.dart';
import '../../utils/json_validator.dart';
import '../../utils/magic_nums.dart';
import '../data/user_handler.dart';
import 'user.dart';

class UserReceiver {
  User user;

  UserReceiver(this.user);

  //{'m': [ewoiweur oiwe roweiur woeiru woer u i], 't': ['userID'], 'k': 'id'} >
  void handleData(dynamic data) async {
    // raw data from websocket
    if (!JSONValidate.isValidJSON(data, requiredKeys: [MagicNumber.MESSAGE_COMPILATION])) {
      ELog.e("User ${user.uuid} sent invalid data.");
      return;
    }
    Map<String, dynamic> jsonEnc = jsonDecode(data);
    List<String> serverEncryptedList = (jsonEnc[MagicNumber.MESSAGE_COMPILATION] as List).cast<String>();

    String decodedJson = await (EncryptionUtil.decryptParts(serverEncryptedList, user.encrypter));
    if (!JSONValidate.isValidJSON(decodedJson)) {
      ELog.e("Received invalid json.");
      return;
    }
    Map json = jsonDecode(decodedJson);

    if (JSONValidate.isValidJSON(decodedJson, requiredKeys: [MagicNumber.CLIENT_FINISHED_AUTHENTICATION])) {
      user.unloadCache();
      bool b = json[MagicNumber.CLIENT_FINISHED_AUTHENTICATION];
      user.showOnlineStatus = b;
      return;
    }

    if (JSONValidate.isValidJSON(decodedJson, requiredKeys: [MagicNumber.PUBLIC_KEY_DELIM, MagicNumber.TO_USER])) {
      // this is a key exchange.
      User? targetUser = await UserHandler().getOrLoadUser(json[MagicNumber.TO_USER][0]);
      if (targetUser == null) {
        ELog.e("${user.uuid} tried to send a key exchange to an invalid user. (${json[MagicNumber.TO_USER][0]})");
        return;
      }
      Map intraOutMap = {MagicNumber.FROM_USER: user.uuid, MagicNumber.PUBLIC_KEY_DELIM: json[MagicNumber.PUBLIC_KEY_DELIM]};
      String intraOut = jsonEncode(intraOutMap);
      targetUser.receiver.intraserverMessage(intraOut);
      ELog.i("Handling legacy key exchange.");
      return;
    }

    if (JSONValidate.isValidJSON(decodedJson, requiredKeys: [MagicNumber.ENCRYPTED_KEY_EXCHANGE, MagicNumber.TO_USER])) {
      List toUser = json[MagicNumber.TO_USER];
      List data = json[MagicNumber.ENCRYPTED_KEY_EXCHANGE];

      String targetUser = toUser[0].toString();
      Map newOut = {MagicNumber.FROM_USER: user.uuid, MagicNumber.ENCRYPTED_KEY_EXCHANGE: data};
      String dataOut = jsonEncode(newOut);
      User? targetUserObj = await UserHandler().getOrLoadUser(targetUser);
      if (targetUserObj == null) {
        ELog.e("${user.uuid} tried to send a key exchange to an invalid user. $targetUser");
        return;
      }
      ELog.i("Performing encrypted key exchange.");
      targetUserObj.receiver.intraserverMessage(dataOut);
      return;
    }

    if (JSONValidate.isValidJSON(decodedJson, requiredKeys: [MagicNumber.ONLINE])) {
      if (json[MagicNumber.ONLINE] is! List) {
        return;
      }
      List<String> all = ((json[MagicNumber.ONLINE] as List).cast<String>());
      Map response = {};
      for (String query in all) {
        User? user = UserHandler().getUser(uuid: query);
        bool online = false;
        if (user != null) {
          online = user.isOnline();
        }
        response[query] = online;
      }
      await user.sendMessage(jsonEncode({MagicNumber.ONLINE: 'r', MagicNumber.ACTIVE: response}));
      return;
    }

    if (!JSONValidate.isValidJSON(decodedJson, requiredKeys: [MagicNumber.TO_USER, MagicNumber.MESSAGE_COMPILATION])) {
      ELog.e("Encrypted data is invalid. ${user.uuid} $decodedJson");
      return;
    }

    List<String> to = (json[MagicNumber.TO_USER] as List).cast<String>();
    String? keyID;
    if (json.containsKey(MagicNumber.KEY_ID)) {
      keyID = json[MagicNumber.KEY_ID];
    }
    if (to.length > 1 && keyID == null) {
      ELog.e("User ${user.uuid} tried to send a message to multiple users without a keyID.");
      return;
    }

    Map<String, dynamic> outData = {MagicNumber.MESSAGE_COMPILATION: json[MagicNumber.MESSAGE_COMPILATION], MagicNumber.FROM_USER: user.uuid};
    if (keyID != null) {
      outData[MagicNumber.KEY_ID] = keyID;
    }

    String intraOut = jsonEncode(outData);

    for (String uuid in to) {
      User? targetUser = await UserHandler().getOrLoadUser(uuid);
      if (targetUser == null) {
        ELog.e("${user.uuid} tried to send a message to an invalid user. ($uuid)");
        continue;
      }
      targetUser.receiver.intraserverMessage(intraOut);
    }
  }

  void intraserverMessage(String out) {
    if (user.hasActiveBackgroundConnection()) {
      user.sendMessage(out);
    } else {
      user.addToCache(out);
    }
  }
}
