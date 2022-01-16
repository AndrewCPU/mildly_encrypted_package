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


  static String timeIncrement(int milliseconds) {
    Duration duration = Duration(milliseconds: milliseconds);
    if (milliseconds <= 1) {
      return "Never";
    }
    if (duration.inSeconds < 60) {
      String s = duration.inSeconds == 1 ? '' : 's';
      return duration.inSeconds.toString() + " second$s";
    }
    if (duration.inMinutes < 60) {
      String s = duration.inMinutes == 1 ? '' : 's';
      return duration.inMinutes.toString() + " minute$s";
    }
    if (duration.inHours < 24) {
      String s = duration.inHours == 1 ? '' : 's';
      return duration.inHours.toString() + " hour$s";
    }
    if (duration.inDays < 7) {
      String s = duration.inDays == 1 ? '' : 's';
      return duration.inDays.toString() + " day$s";
    } else if (duration.inDays == 7) {
      return "1 week";
    }
    return ">1 week";
  }
}
