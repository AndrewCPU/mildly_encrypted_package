import 'dart:math';

import '../../utils/magic_nums.dart';

class AuthenticationData {
  List<int> codes;
  late int expiration;
  AuthenticationData(this.codes) {
    expiration =
        DateTime.now().millisecondsSinceEpoch + MagicNumber.HANDSHAKE_TIMEOUT;
  }

  static AuthenticationData generate() {
    Random random = Random();
    List<int> codes = [];
    codes.add(random.nextInt(MagicNumber.MAX_VERIFICATION_CODE));
    codes.add(random.nextInt(MagicNumber.MAX_VERIFICATION_CODE));
    return AuthenticationData(codes);
  }
}
