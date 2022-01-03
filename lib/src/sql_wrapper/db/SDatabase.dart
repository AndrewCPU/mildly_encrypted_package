abstract class SDatabase {
  bool isOpen();
  Future<List<Map>> query(String table,
      {bool? distinct,
      List<String>? columns,
      String? where,
      List<Object?>? whereArgs,
      String? groupBy,
      String? having,
      String? orderBy,
      int? limit,
      int? offset});
  Future<int> insert(String table, Map<String, Object?> values);
  Future<int> update(String table, Map<String, Object?> values, {String? where, List<Object?>? whereArgs});
  // Future<List<Map<String, Object?>>> rawQuery(String sql,
  //     [List<Object?>? arguments]);
  Future<void> init();
  Future<void> createTable(String tableName, List<String> columns);
  Future<void> delete(String table, {String? where, List<Object?>? whereArgs});
  Future<void> reset();

  Future<void> deleteTable(String tableName);
}
