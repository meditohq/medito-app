sealed class AppError implements Exception {
  final String message;
  const AppError({this.message = 'An unknown error occurred'});

  @override
  String toString() => message;
}

// General Errors
final class UnknownError extends AppError {
  const UnknownError({super.message = 'Unknown error'});
}

final class NoInternetError extends AppError {
  const NoInternetError({super.message = 'No internet connection'});
}

final class TimeoutError extends AppError {
  const TimeoutError({super.message = 'Request timed out'});
}

// Server Errors
final class ServerError extends AppError {
  const ServerError({super.message = 'Server error'});
}

final class NotFoundError extends AppError {
  const NotFoundError({super.message = 'Resource not found'});
}

// Auth Errors
final class UnauthorizedError extends AppError {
  const UnauthorizedError({super.message = 'Unauthorized'});
}

final class RefreshTokenError extends AppError {
  const RefreshTokenError(
      {super.message = 'Session expired. Please log in again.'});
}

final class RateLimitError extends AppError {
  final int? tryAfterSeconds;

  const RateLimitError({
    super.message = 'Too many requests. Please try again later.',
    this.tryAfterSeconds,
  });
}

final class EmailExistsError extends AppError {
  final String? email;

  const EmailExistsError({
    this.email,
    super.message = 'This device is already associated with an email account.',
  });
}
