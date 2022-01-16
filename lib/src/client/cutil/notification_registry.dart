import 'package:mildly_encrypted_package/src/client/cutil/core/CoreEventType.dart';
import 'package:mildly_encrypted_package/src/client/cutil/core/core_event_registry.dart';
import 'package:mildly_encrypted_package/src/client/cutil/ui_notify.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientGroupChat.dart';
import 'package:mildly_encrypted_package/src/client/objs/ClientUser.dart';

class UpdateNotificationRegistry {
  static final UpdateNotificationRegistry _instance = UpdateNotificationRegistry._internal();
  UpdateNotificationRegistry._internal();
  factory UpdateNotificationRegistry() {
    return _instance;
  }

  static UpdateNotificationRegistry getInstance() {
    return _instance;
  }

  final List<ClientNotifier> listeners = [];

  List<ClientNotifier> getListeners(List<String> listeningFor) {
    List<ClientNotifier> notifiers = [];
    for (ClientNotifier notifier in listeners) {
      for (String u in listeningFor) {
        if (notifier.getListeningFor().contains(u)) {
          if (!notifiers.contains(notifier)) {
            notifiers.add(notifier);
          }
        }
      }
    }
    return notifiers;
  }

  void fileUploadProgress(ClientUser chat) {
    getListeners([chat.uuid]).forEach((element) {
      element.sendProgressUpdate();
    });
  }

  void fileDownloadProgress(ClientUser chat) {
    getListeners([chat.uuid]).forEach((element) {
      element.downloadProgressUpdate();
    });
  }

  void messageUpdate(ClientUser chat, String messageID) {
    List<ClientNotifier> listeners = getListeners([chat.uuid]);
    for (ClientNotifier listener in listeners) {
      if (chat is ClientGroupChat) {
        listener.groupMessageUpdate(chat, messageID);
      } else {
        listener.userMessageUpdate(chat, messageID);
      }
    }
  }

  void newMessage(ClientUser chat, String messageID) {
    List<ClientNotifier> listeners = getListeners([chat.uuid]);
    for (ClientNotifier listener in listeners) {
      if (chat is ClientGroupChat) {
        listener.newGroupMessage(chat, messageID);
      } else {
        listener.newUserMessage(chat, messageID);
      }
    }
    CoreEventRegistry().notify(CoreEventType.CHAT_REORDER, data: 'data');
  }

  void newPicture(ClientUser user, String path) {
    List<ClientNotifier> listeners = getListeners([user.uuid]);
    for (ClientNotifier listener in listeners) {
      if (user is ClientGroupChat) {
        listener.groupProfileChange(user, path);
      } else {
        listener.userProfileChange(user, path);
      }
    }
  }

  void newName(ClientUser user, String path) {
    List<ClientNotifier> listeners = getListeners([user.uuid]);
    for (ClientNotifier listener in listeners) {
      if (user is ClientGroupChat) {
        listener.groupNameChange(user, path);
      } else {
        listener.userNameChange(user, path);
      }
    }
  }

  void typingChange(ClientUser user) {
    List<ClientNotifier> listeners = getListeners([user.uuid]);
    for (ClientNotifier listener in listeners) {
      if (user is ClientGroupChat) {
        listener.groupTypingIndicator(user);
      } else {
        listener.userTypingIndicator(user);
      }
    }
  }

  void registerListener(ClientNotifier notifier) {
    listeners.add(notifier);
  }

  void unregisterListener(ClientNotifier notifier) {
    listeners.remove(notifier);
  }
}
