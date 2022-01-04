import 'package:mildly_encrypted_package/src/client/cutil/core/CoreEventType.dart';

abstract class CoreListener{
  CoreEventType getType();
  void notify({String? data});
}