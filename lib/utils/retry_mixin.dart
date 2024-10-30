import 'package:flutter/foundation.dart';

mixin RetryMixin {
  Future<T> retryOperation<T>({
    required Future<T> Function() operation,
    String errorMessage = 'Operation failed',
    int maxAttempts = 3,
    Duration delay = const Duration(seconds: 2),
  }) async {
    var attempts = 0;
    while (attempts < maxAttempts) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        if (attempts == maxAttempts) {
          if (kDebugMode) {
            print('$errorMessage after $maxAttempts attempts: $e');
          }
          rethrow;
        }
        await Future.delayed(delay * attempts);
      }
    }
    throw Exception(errorMessage);
  }
} 