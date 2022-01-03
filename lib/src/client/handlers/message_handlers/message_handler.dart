abstract class MessageHandler {
  bool check(String message, String from, {String? keyID});
  void handle(String message, String from, {String? keyID});
  String getHandlerName();
}
