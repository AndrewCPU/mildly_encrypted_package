import 'package:mildly_encrypted_package/mildly_encrypted_package.dart';

abstract class ClientNotifier {
  List<String> getListeningFor();

  void userNameChange(ClientUser user, String newName);
  void userProfileChange(ClientUser user, String newProfilePath);
  void newUserMessage(ClientUser user, String messageUuid);
  void userMessageUpdate(ClientUser user, String messageUuid);
  void userTypingIndicator(ClientUser user);

  void groupNameChange(ClientGroupChat user, String newName);
  void groupProfileChange(ClientGroupChat user, String newProfilePath);
  void newGroupMessage(ClientGroupChat user, String messageUuid);
  void groupMessageUpdate(ClientGroupChat user, String messageUuid);
  void groupTypingIndicator(ClientGroupChat user);

  void sendProgressUpdate();
  void downloadProgressUpdate();
}
