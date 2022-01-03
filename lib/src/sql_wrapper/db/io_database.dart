import 'dart:io';

import 'package:mildly_encrypted_package/src/logging/ELog.dart';
import 'package:sqflite/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'SDatabase.dart';

class IODatabase implements SDatabase {
  //sqlflite version

  late Database wrapped;
  @override
  Future<void> createTable(String tableName, List<String> columns) async {
    String data = "";
    for (String column in columns) {
      data += column + ", ";
    }
    data = data.substring(0, data.length - 2);
    String sql = 'CREATE TABLE IF NOT EXISTS `$tableName` ($data);';
    await wrapped.rawQuery(sql);
    return;
  }

  @override
  Future<void> deleteTable(String tableName) async {
    await wrapped.execute('DROP TABLE IF EXISTS `$tableName`;');
  }

  @override
  Future<int> insert(String table, Map<String, Object?> values) async {
    return await wrapped.insert('`$table`', values);
  }

  @override
  bool isOpen() {
    return wrapped.isOpen;
  }

  @override
  Future<List<Map>> query(String table,
      {bool? distinct,
      List<String>? columns,
      String? where,
      List<Object?>? whereArgs,
      String? groupBy,
      String? having,
      String? orderBy,
      int? limit,
      int? offset}) async {
    return await wrapped.query('`$table`', distinct: distinct, columns: columns, whereArgs: whereArgs, where: where);
  }

  @override
  Future<int> update(String table, Map<String, Object?> values, {String? where, List<Object?>? whereArgs}) async {
    var d = await wrapped.update('`$table`', values, where: where, whereArgs: whereArgs);
    return d;
  }

  String path;
  IODatabase(this.path);

  Future<void> reset() async {
    await wrapped.close();
    File f = File(wrapped.path);
    await f.delete();
    init();
  }

  @override
  Future<void> init() async {
    var factory = databaseFactoryFfi;
    var db = await factory.openDatabase(path);
    wrapped = db;
    ELog.i("Opened " + wrapped.path);
  }

  @override
  Future<void> delete(String table, {String? where, List<Object?>? whereArgs}) async {
    await wrapped.delete(table, where: where, whereArgs: whereArgs);
  }
}
