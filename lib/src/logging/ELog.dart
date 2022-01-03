import 'package:intl/intl.dart';

import 'logging_cat.dart';

class ELog {
  static void log(Object message, {LogCat? cat}) {
    cat ??= LogCat.info;
    DateTime now = DateTime.now();
    DateFormat format = DateFormat.yMd().add_jms();
    String f = format.format(now);
    print(
        "$f [${cat.toString().replaceAll('LogCat.', '')}] ${message.toString()}");
  }

  static void i(Object o) {
    log(o, cat: LogCat.info);
  }

  static void e(Object o) {
    log(o, cat: LogCat.error);
  }

  static void a(Object o) {
    log(o, cat: LogCat.authentication);
  }
}
