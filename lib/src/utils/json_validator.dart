import 'dart:convert';

class JSONValidate {
  static bool isValidJSON(String json, {List<String> requiredKeys = const []}) {
    try {
      Map m = jsonDecode(json);
      for (String key in requiredKeys) {
        if (!(m.containsKey(key))) {
          return false;
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}
