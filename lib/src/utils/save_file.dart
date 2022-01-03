import 'dart:convert';
import 'dart:io';

class SaveFile {
  static final Map<String, SaveFile> _instances = {};

  static Future<SaveFile> getInstance({String path = './data.json'}) async {
    if (_instances.containsKey(path) && !(await _instances[path]!._externallyChanged())) {
      return _instances[path]!;
    }
    _instances[path] = await SaveFile._internal(path: path).loadInstance();
    return _instances[path]!;
  }

  String path;
  Map<String, dynamic>? _data;
  SaveFile._internal({this.path = "./data.json"});
  int? lastModified;

  Future<SaveFile> loadInstance() async {
    File file = File(path);
    String contents;
    if (await file.exists()) {
      contents = await file.readAsString();
    } else {
      contents = jsonEncode({});
    }
    _data = jsonDecode(contents);
    await _updateLastModified();
    return this;
  }

  Future<void> setString(String key, String value) async {
    await set(key, value);
  }

  Future<void> setStringList(String key, List<String> value) async {
    await set(key, value);
  }

  Future<void> setInt(String key, int i) async {
    await set(key, i);
  }

  Future<void> setDouble(String key, double d) async {
    await set(key, d);
  }

  Future<void> setList(String key, List value) async {
    await set(key, value);
  }

  Future<void> setMap(String key, Map map) async {
    await set(key, map);
  }

  Future<void> set(String key, Object o) async {
    _data?[key] = o;
    await _save();
  }

  bool containsKey(String key) {
    return _data?.containsKey(key) ?? false;
  }

  Future<String?> getString(String key) async {
    return await get<String>(key);
  }

  Future<int?> getInt(String key) async {
    return await get<int>(key);
  }

  Future<Map?> getMap(String key) async {
    return await get<Map>(key);
  }

  Future<double?> getDouble(String key) async {
    return await get<double>(key);
  }

  Future<List<String>?> getStringList(String key) async {
    return await getList<String>(key);
  }

  Future<List<int>?> getIntList(String key) async {
    return await getList<int>(key);
  }

  Future<List<double>?> getDoubleList(String key) async {
    return await getList<double>(key);
  }

  Future<List<T>?> getList<T>(String key) async {
    if (!containsKey(key)) {
      return null;
    }
    return ((await get<List>(key))!).cast<T>();
  }

  Future<T?> get<T>(String key) async {
    if (!containsKey(key)) {
      return null;
    }
    return _data?[key] as T;
  }

  Future<void> clear() async {
    _data?.clear();
    await _save();
  }

  //

  Future<bool> _externallyChanged() async {
    final stat = await FileStat.stat(path);
    return (lastModified != stat.modified.millisecondsSinceEpoch);
  }

  Future<void> _updateLastModified() async {
    final stat = await FileStat.stat(path);
    lastModified = stat.modified.millisecondsSinceEpoch;
  }

  Future<void> _save() async {
    File file = File(path);
    await file.writeAsString(jsonEncode(_data), flush: true);
    await _updateLastModified();
  }
}
