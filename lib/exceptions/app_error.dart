import 'package:medito/constants/strings/string_constants.dart';

sealed class AppError implements Exception {
  final String message;
  const AppError({this.message = StringConstants.errorUnknownMessage});

  @override
  String toString() => message;
}

// General Errors
final class UnknownError extends AppError {
  const UnknownError({super.message = StringConstants.errorUnknownMessage});
}

final class NoInternetError extends AppError {
  const NoInternetError(
      {super.message = StringConstants.errorNoInternetMessage});
}

final class TimeoutError extends AppError {
  const TimeoutError({super.message = StringConstants.errorTimeoutMessage});
}

// Server Errors
final class ServerError extends AppError {
  const ServerError({super.message = StringConstants.errorServerMessage});
}

final class NotFoundError extends AppError {
  const NotFoundError({super.message = StringConstants.errorNotFoundMessage});
}

// Auth Errors
final class UnauthorizedError extends AppError {
  const UnauthorizedError(
      {super.message = StringConstants.errorUnauthorizedMessage});
}

final class RefreshTokenError extends AppError {
  const RefreshTokenError(
      {super.message = StringConstants.errorUnauthorizedMessage});
}

final class RateLimitError extends AppError {
  final int? tryAfterSeconds;

  const RateLimitError({
    super.message = StringConstants.someThingWentWrong,
    this.tryAfterSeconds,
  });
}

final class EmailExistsError extends AppError {
  final String? email;

  const EmailExistsError({
    this.email,
    super.message = StringConstants.emailExistsDialogMessage,
  });
}

final class InactiveEmailError extends AppError {
  const InactiveEmailError({
    super.message = StringConstants.inactiveEmailError,
  });
}
