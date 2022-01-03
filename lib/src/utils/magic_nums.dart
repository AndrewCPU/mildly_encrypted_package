class MagicNumber {
  static final int ENCRYPTION_MESSAGE_SIZE = 42;
  static final int HANDSHAKE_TIMEOUT = Duration(seconds: 30).inMilliseconds;
  static final int MAX_VERIFICATION_CODE = 2048;
  static final int TYPING_TIMEOUT_IN_MS = Duration(seconds: 5).inMilliseconds;

  static final String USER_ID_DELIM = 'u';
  static final String CODE_1_DELIM = 'c';
  static final String CODE_2_DELIM = 'd';
  static final String PUSH_NOTIFICATION_DELIM = 'n';
  static final String PUBLIC_KEY_DELIM = 'p';
  static final String MESSAGE_COMPILATION = 'm';
  static final String TO_USER = 't';
  static final String KEY_ID = 'k';
  static final String FROM_USER = 'f';
  static final String STATUS = 'status';
  static final String ACTIVE = 'a';
  static final String SERVER_ADDRESS = "dialchat.app";
}
