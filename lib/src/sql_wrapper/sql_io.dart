import 'package:mildly_encrypted_package/src/logging/ELog.dart';

import 'db/SDatabase.dart';
import 'db/io_database.dart';
import 'sql_wrapper.dart';

class SQLWrap implements SQLFactory {
  @override
  Future<SDatabase> openDatabase(String path) async {
    ELog.i("Opening IO DB @ $path");
    SDatabase db = IODatabase(path);
    await db.init();
    return db;
  }
}
