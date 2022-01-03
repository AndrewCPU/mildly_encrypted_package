import '../../../logging/ELog.dart';
import '../../../utils/string_util.dart';
import 'SColumn.dart';
import 'SRow.dart';
import 'column_flags.dart';

class STable {
  String tableName;
  List<SColumn> columns;
  List<SRow> rows = [];

  STable({required this.tableName, required this.columns});

  List<Map> toTableDeclaration() {
    List<Map> declar = [];
    for (SColumn col in columns) {
      declar.add(col.toMap());
    }
    return declar;
  }

  void loadRowsFromList(List<Map> rows) {
    this.rows.clear();
    for (Map item in rows) {
      this.rows.add(SRow.fromMap(item, columns));
    }
  }

  List<Map> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
  }) {
    List<Map> answers = [];

    List<SRow> rowOrdered = List.from(rows);
    if (orderBy != null) {
      List<String> data = orderBy.split(" ");
      String columnName = data[0];
      String order = "ASC";
      if (data.length > 1) {
        order = data[1];
      }
      order = order.toUpperCase();
      rowOrdered.sort((rowA, rowB) => order == 'ASC'
          ? rowA
              .getValue(columnName: columnName)
              .toString()
              .compareTo(rowB.getValue(columnName: columnName).toString())
          : rowB
              .getValue(columnName: columnName)
              .toString()
              .compareTo(rowA.getValue(columnName: columnName).toString()));
    }

    List<String> splitAndReplacedWhere = [];
    if (where != null) {
      int params = StringUtils.count(where, '?');
      if (params > 0) {
        for (int i = 0; i < params; i++) {
          where = where!.replaceFirst('?', whereArgs![i].toString());
        }
      }
      splitAndReplacedWhere = where!.split('AND');
    }

    _outer:
    for (SRow row in rowOrdered) {
      for (String spl in splitAndReplacedWhere) {
        String dt = spl.replaceAll(
            " ", ""); // server_ip=127.0.0.1, value cannot have spaces.
        List<String> pointVal = dt.split("=");
        if (row.getValue(columnName: pointVal[0].toString()) !=
            pointVal[1].toString()) {
          continue _outer;
        }
      }
      answers.add(row.toMap());
      if (limit != null && answers.length == limit) {
        break;
      }
    }
    return answers;
  }

  void update(Map data, {String? where, List<Object?>? whereArgs}) {
    List<SRow> answers = [];

    List<String> splitAndReplacedWhere = [];
    if (where != null) {
      int params = StringUtils.count(where, '?');
      if (params > 0) {
        for (int i = 0; i < params; i++) {
          where = where!.replaceFirst('?', whereArgs![i].toString());
        }
      }
      splitAndReplacedWhere = where!.split('AND');
    }

    _outer:
    for (SRow row in rows) {
      for (String spl in splitAndReplacedWhere) {
        String dt = spl.replaceAll(
            " ", ""); // server_ip=127.0.0.1, value cannot have spaces.
        List<String> pointVal = dt.split("=");
        if (row.getValue(columnName: pointVal[0].toString()) !=
            pointVal[1].toString()) {
          continue _outer;
        }
      }
      answers.add(row);
    }
    Map<SColumn, Object> keyValueMap = {};
    for (String key in data.keys) {
      keyValueMap[getColumnByName(key)!] = data[key];
    }
    for (SColumn col in keyValueMap.keys) {
      for (SRow a in answers) {
        a.withValue(col, keyValueMap[col]!);
      }
    }
    return;
  }

  SColumn? getColumnByName(String name) {
    for (SColumn col in columns) {
      if (col.columnName == name) {
        return col;
      }
    }
    return null;
  }

  void insert(Map data) {
    SRow row = SRow();
    for (String key in data.keys) {
      SColumn? col = getColumnByName(key);
      if (col == null) {
        ELog.e("Cannot insert into column. Invalid name: $key");
        return;
      }
      if (col.flags.contains(ColumnFlag.primary)) {
        for (SRow row in rows) {
          if (row.getValue(columnName: col.columnName) == data[key]) {
            ELog.e("Non unique primary key found.");
            return;
          }
        }
      }
      if (col.flags.contains(ColumnFlag.autoincrement) && data[key] == null) {
        int lastVal = -1;
        for (SRow row in rows) {
          Object? l = row.getValue(columnName: col.columnName);
          if (l != null) {
            lastVal = l as int;
          }
        }
        data[key] = lastVal;
      }
      row.withValue(col, data[key]);
    }
    rows.add(row);
  }

  static STable fromTableDeclaration(String tableName, List<Map> declar) {
    List<SColumn> cols = [];
    for (Map item in declar) {
      SColumn col = SColumn.fromMap(item);
      cols.add(col);
    }
    return STable(tableName: tableName, columns: cols);
  }
}
