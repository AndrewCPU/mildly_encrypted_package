import 'dart:io';
import 'db/SDatabase.dart';
import 'sql_io.dart' if (dart.library.ui) 'sql_ui.dart';

// import 'sql_io.dart';
// import 'sql_ui.dart';

abstract class SQLFactory {
  factory SQLFactory() {
    // if (Platform.isWindows || Platform.isLinux) {
    return SQLWrap();
    // }
    // return SQLUI();
  }

  Future<SDatabase> openDatabase(String path);
}
