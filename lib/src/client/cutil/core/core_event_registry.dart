import 'package:mildly_encrypted_package/src/client/cutil/core/CoreEventType.dart';
import 'package:mildly_encrypted_package/src/client/cutil/core/core_listener.dart';

class CoreEventRegistry {
  static final CoreEventRegistry _instance = CoreEventRegistry._internal();
  CoreEventRegistry._internal();
  factory CoreEventRegistry() {
    return _instance;
  }

  List<CoreListener> _listeners = [];

  void addListener(CoreListener listener) {
    _listeners.add(listener);
  }

  void removeListener(CoreListener listener) {
    _listeners.remove(listener);
  }

  void notify(CoreEventType type, {String? data}) {
    for (CoreListener listener in _listeners) {
      if (listener.getType() == type) {
        listener.notify(data: data);
      }
    }
  }
}
