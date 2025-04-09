import 'package:flutter/foundation.dart';
import 'package:medito/exceptions/app_error.dart';

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
          AppLogger.e('RETRY', '$errorMessage after $maxAttempts attempts: $e');
          if (e is AppError) {
            rethrow;
          }
          throw const ServerError();
        }
        await Future.delayed(delay * attempts);
      }
    }
    throw const ServerError();
  }
}

import 'logger.dart';