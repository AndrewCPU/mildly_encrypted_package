// import 'package:mildly_encrypted_package/src/sql_wrapper/db/ui_database.dart';

import 'package:mildly_encrypted_package/src/logging/ELog.dart';

import 'db/SDatabase.dart';
import 'db/ui_database.dart';
import 'sql_wrapper.dart';

class SQLWrap implements SQLFactory {
  @override
  Future<SDatabase> openDatabase(String path) async {
    ELog.i("Opening UI DB @ $path");
    SDatabase w = UIDatabase(path);
    await w.init();
    return w;
  }
}
