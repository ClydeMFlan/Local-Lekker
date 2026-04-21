class Utils {
  static String truncate(String s, [int len = 50]) =>
      s.length <= len ? s : '${s.substring(0, len)}...';
}
