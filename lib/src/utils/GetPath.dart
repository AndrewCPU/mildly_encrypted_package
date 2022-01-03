class GetPath {
  static GetPath? _instance;
  static void initialize(String path) {
    _instance = GetPath(path);
  }

  static GetPath getInstance() {
    return _instance!;
  }

  String path;
  GetPath(this.path);
}
