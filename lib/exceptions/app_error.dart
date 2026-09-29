import 'dart:io';

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

/// Why a request never got an HTTP response. Dart reports all of these as a
/// [SocketException], but only [offline] means the device has no network;
/// the others happen with working internet when the API host specifically
/// can't be resolved or reached (DNS filters, per-app network restrictions,
/// slow or blocked routes to the edge).
enum NetworkFailureKind {
  /// Generic: network unreachable, no route, or an unrecognised OS error.
  offline,

  /// DNS lookup for the host failed ("Failed host lookup", EAI_NONAME).
  hostLookup,

  /// TCP connect did not complete within [HttpClient.connectionTimeout].
  connectTimeout,

  /// The host answered but refused or dropped the connection.
  connectionRefused,
}

final class NetworkConnectionError extends AppError {
  final Object? originalException;
  final NetworkFailureKind kind;

  const NetworkConnectionError({
    super.message = 'No internet connection',
    this.originalException,
    this.kind = NetworkFailureKind.offline,
  });

  /// Classifies a [SocketException] so the UI can say something more useful
  /// than "No internet connection" when the phone is clearly online.
  factory NetworkConnectionError.fromSocketException(SocketException e) {
    final kind = classifySocketException(e);
    return NetworkConnectionError(
      message: switch (kind) {
        NetworkFailureKind.hostLookup =>
          "Couldn't reach Medito's servers. Check for a VPN, ad blocker or Private DNS setting.",
        NetworkFailureKind.connectTimeout =>
          "Connection to Medito's servers timed out. Please try again.",
        NetworkFailureKind.connectionRefused =>
          "Couldn't connect to Medito's servers. Please try again later.",
        NetworkFailureKind.offline => 'No internet connection',
      },
      originalException: e,
      kind: kind,
    );
  }

  /// One-line summary of the underlying OS error, for logging.
  String get detail {
    final e = originalException;
    if (e is SocketException) {
      final os = e.osError;
      return os == null
          ? e.message
          : '${e.message} (${os.message}, errno ${os.errorCode})';
    }
    return e?.toString() ?? message;
  }

  static NetworkFailureKind classifySocketException(SocketException e) {
    final text = '${e.message} ${e.osError?.message ?? ''}'.toLowerCase();
    final errno = e.osError?.errorCode;

    if (text.contains('failed host lookup') ||
        text.contains('no address associated with hostname') ||
        text.contains('name or service not known') ||
        text.contains('nodename nor servname')) {
      return NetworkFailureKind.hostLookup;
    }
    // dart:io raises this when HttpClient.connectionTimeout elapses.
    if (text.contains('connection timed out') ||
        errno == 110 /* ETIMEDOUT linux */ ||
        errno == 60 /* ETIMEDOUT darwin */ ) {
      return NetworkFailureKind.connectTimeout;
    }
    if (text.contains('connection refused') ||
        text.contains('connection reset') ||
        text.contains('broken pipe') ||
        errno == 111 /* ECONNREFUSED linux */ ||
        errno == 61 /* ECONNREFUSED darwin */ ||
        errno == 104 /* ECONNRESET */ ) {
      return NetworkFailureKind.connectionRefused;
    }
    return NetworkFailureKind.offline;
  }
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
