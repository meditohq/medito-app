class SessionExpiredException implements Exception {
  final String message;
  
  const SessionExpiredException([this.message = 'Session has expired']);
  
  @override
  String toString() => message;
} 