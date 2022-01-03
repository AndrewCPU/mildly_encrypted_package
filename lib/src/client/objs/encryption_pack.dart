abstract class EncryptionPack {
  Future<void> sendDataPacket(String message);
  Future<void> updateProfilePicturePath(String path);
  Future<void> updateUsername(String username);
  String decryptFromUser(List<String> messageParts);
  Future<String> sendChatMessage(String messageContent, {Map? specialData});
}
