sealed class AppError {
  const AppError();
}

final class NetworkError extends AppError {
  const NetworkError();
}

final class NoInternetError extends AppError {
  const NoInternetError();
}

final class TimeoutError extends AppError {
  const TimeoutError();
}

final class UnauthorizedError extends AppError {
  const UnauthorizedError();
}

final class RefreshTokenError extends AppError {
  const RefreshTokenError();
}

final class NotFoundError extends AppError {
  const NotFoundError();
}

final class ServerError extends AppError {
  const ServerError();
}

final class UnknownError extends AppError {
  const UnknownError();
}
