class StringUtils {
  static List<String> breakToPieces(String message, int size) {
    String temp = '';
    List<String> parts = [];
    for (int i = 0; i < message.length; i++) {
      String c = message[i];
      temp += c;
      if (temp.length == size) {
        parts.add(temp);
        temp = '';
      }
    }
    if (temp.isNotEmpty) {
      parts.add(temp);
    }
    return parts;
  }

  static int count(String message, String target) {
    int count = 0;
    for (int i = 0; i < message.length; i++) {
      if (message[i] == target) {
        count++;
      }
    }
    return count;
  }
}
