/// 统一日志工具
class Logger {
  static const String _tag = 'LanChat';
  static bool _enabled = true;

  static void enable() => _enabled = true;
  static void disable() => _enabled = false;

  static void d(String message) {
    if (_enabled) print('[$_tag/D] $message');
  }

  static void i(String message) {
    if (_enabled) print('[$_tag/I] $message');
  }

  static void w(String message) {
    if (_enabled) print('[$_tag/W] $message');
  }

  static void e(String message, [Object? error, StackTrace? stack]) {
    if (_enabled) {
      print('[$_tag/E] $message');
      if (error != null) print('[$_tag/E] Error: $error');
      if (stack != null) print('[$_tag/E] Stack: $stack');
    }
  }
}
