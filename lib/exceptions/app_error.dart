sealed class AppError implements Exception {
  final String message;
  const AppError({this.message = 'Something went wrong, please try again'});

  @override
  String toString() => message;
}

// General Errors
final class UnknownError extends AppError {
  const UnknownError({
    super.message = 'Something went wrong, please try again',
  });
}

final class NetworkConnectionError extends AppError {
  final Object? originalException;

  const NetworkConnectionError({
    super.message = 'No internet connection',
    this.originalException,
  });
}

final class TimeoutError extends AppError {
  const TimeoutError({super.message = 'Connection timed out'});
}

// Server Errors
final class ServerError extends AppError {
  const ServerError({super.message = 'Server error, please try again later'});
}

final class NotFoundError extends AppError {
  const NotFoundError({super.message = 'Content not found'});
}

// Auth Errors
final class UnauthorizedError extends AppError {
  const UnauthorizedError({
    super.message = 'Session expired, please sign in again',
  });
}

final class RefreshTokenError extends AppError {
  const RefreshTokenError({
    super.message = 'Session expired, please sign in again',
  });
}

final class RateLimitError extends AppError {
  final int? tryAfterSeconds;

  const RateLimitError({
    super.message = 'Something went wrong',
    this.tryAfterSeconds,
  });
}

final class EmailExistsError extends AppError {
  final String? email;

  const EmailExistsError({
    this.email,
    super.message =
        'Looks like you have signed in with an email address before. Would you like to sign in with your email address again?',
  });
}

/// Error indicating that the client ID is already associated with a different email address.
final class EmailMismatchError extends AppError {
  const EmailMismatchError({
    super.message =
        'This account is already linked to a different email address. Please use the original email.',
  });
}

/// Error indicating an issue reading from local storage (SharedPreferences or SecureStorage).
class StorageReadError extends AppError {
  const StorageReadError({
    super.message = 'Failed to read data from local storage',
  });
}

/// Error indicating that the email provided is associated with an inactive account.
class InactiveEmailError extends AppError {
  const InactiveEmailError({
    super.message =
        'This email address is currently unable to receive messages due to email provider restrictions or delivery issues. Please try using a different email address.',
  });
}
