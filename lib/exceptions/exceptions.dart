class AppHttpException implements Exception {
  final String message;
  final int? statusCode;

  const AppHttpException(this.message, {this.statusCode});

  @override
  String toString() => '${statusCode ?? ''} $message'.trim();
} 