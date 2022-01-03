class Message {
  String sender;
  String messageUuid;
  int time;
  String messageContent;
  Map data;

  Message(
      {required this.sender,
      required this.messageUuid,
      required this.time,
      required this.messageContent,
      required this.data});
}
