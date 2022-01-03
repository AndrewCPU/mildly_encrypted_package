import 'SColumn.dart';

class SRow {
  Map<SColumn, Object> valueMap = Map.from({});

  SRow({Map<SColumn, Object>? valueMap}) {
    if (valueMap != null) {
      this.valueMap = valueMap;
    }
  }

  void withValue(SColumn col, Object val) {
    valueMap[col] = val;
  }

  Map toMap() {
    Map vals = {};
    for (SColumn key in valueMap.keys) {
      vals[key.columnName] = valueMap[key];
    }
    return vals;
  }

  Object? getValue({SColumn? column, String? columnName}) {
    for (SColumn col in valueMap.keys) {
      if (column != null && column.columnName == col.columnName) {
        return valueMap[col];
      } else if (columnName != null && col.columnName == columnName) {
        return valueMap[col];
      }
    }
    return null;
  }

  static SRow fromMap(Map map, List<SColumn> cols) {
    Map<SColumn, Object> vals = {};
    for (SColumn col in cols) {
      vals[col] = map[col.columnName];
    }
    return SRow(valueMap: vals);
  }
}
