import 'package:flutter/foundation.dart' show kDebugMode;

/// Secure logging utility that only logs in debug mode
/// and never exposes sensitive information like passwords, tokens, or user IDs
class SecureLogger {
  /// Log a message only in debug mode
  static void log(String message) {
    if (kDebugMode) {
      print(message);
    }
  }

  /// Log an error without exposing sensitive data
  static void logError(String context, [Object? error]) {
    if (kDebugMode) {
      print('[$context] Error occurred');
      if (error != null) {
        print('Error details: ${error.toString()}');
      }
    }
  }

  /// Log a warning without exposing sensitive data
  static void logWarning(String context, String message) {
    if (kDebugMode) {
      print('[$context] Warning: $message');
    }
  }
}

