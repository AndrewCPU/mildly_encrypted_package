import 'package:mildly_encrypted_package/src/client/cutil/client_components.dart';

class MessageUpdateBuilder {
  String? messageUpdateType;
  String? messageUuid;
  String? action;
  String? actionValue;

  MessageUpdateBuilder withType(String type) {
    messageUpdateType = type;
    return this;
  }

  MessageUpdateBuilder withUUID(String uuid) {
    messageUuid = uuid;
    return this;
  }

  MessageUpdateBuilder withAction(String action) {
    this.action = action;
    return this;
  }

  MessageUpdateBuilder withValue(String value) {
    actionValue = value;
    return this;
  }

  Map buildMessage() {
    return {
      ClientComponent.MESSAGE_UUID: messageUuid!,
      ClientComponent.MESSAGE_UPDATE: messageUpdateType,
      action: actionValue
    };
  }
}
