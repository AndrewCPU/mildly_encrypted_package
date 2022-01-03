import 'column_flags.dart';
import 'column_type.dart';

class SColumn {
  String columnName;
  ColumnType type;
  List<ColumnFlag> flags;

  SColumn(
      {required this.columnName, required this.type, this.flags = const []});

  Map toMap() {
    return {
      'name': columnName,
      'type': type.toString(),
      'flags': flags.map((e) => e.toString()).toList()
    };
  }

  static SColumn fromMap(Map m) {
    String name = m['name'];
    ColumnType type = ColumnType.values
        .firstWhere((element) => element.toString() == m['type']);
    List<ColumnFlag> flags = (m['flags'] as List)
        .map((e) =>
            ColumnFlag.values.firstWhere((element) => element.toString() == e))
        .toList();
    return SColumn(columnName: name, type: type, flags: flags);
  }
}
