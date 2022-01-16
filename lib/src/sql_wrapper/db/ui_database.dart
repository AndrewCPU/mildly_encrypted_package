import 'dart:io';

import 'package:mildly_encrypted_package/src/logging/ELog.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'SDatabase.dart';

class UIDatabase implements SDatabase {
  //sqlflite version

  late Database wrapped;
  //(id INTEGER PRIMARY KEY AUTOINCREMENT, server_ip TEXT, uuid TEXT, public_key TEXT, private_key TEXT, remote_public_key TEXT, rand_key INTEGER, remote_rand_key INTEGER, data TEXT);
  //createTable(key_logs, [id INTEGER PRIMARY KEY AUTOINCREMENT, ...]);
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
    return await wrapped.query('`$table`', distinct: distinct, columns: columns, whereArgs: whereArgs, orderBy: orderBy, limit: limit, where: where);
  }

  @override
  Future<int> update(String table, Map<String, Object?> values, {String? where, List<Object?>? whereArgs}) async {
    return await wrapped.update('`$table`', values, where: where, whereArgs: whereArgs);
  }

  @override
  Future<void> delete(String table, {String? where, List<Object?>? whereArgs}) async {
    await wrapped.delete('`$table`', where: where, whereArgs: whereArgs);
  }

  @override
  Future<void> deleteTable(String tableName) async {
    await wrapped.execute('DROP TABLE IF EXISTS `$tableName`;');
  }

  // @override
  // Future<List<Map<String, Object?>>> rawQuery(String sql, [List<Object?>? arguments]) async {
  //   // TODO: implement rawQuery
  //   return await wrapped.rawQuery(sql, arguments);
  // }

  String path;
  UIDatabase(this.path);

  Future<void> reset() async {
    await wrapped.close();
    File f = File(wrapped.path);
    await f.delete();
    init();
  }

  @override
  Future<void> init() async {
    wrapped = await openDatabase(join('${await getDatabasesPath()}/$path'));
    ELog.i("Opened " + wrapped.path);
  }
}
