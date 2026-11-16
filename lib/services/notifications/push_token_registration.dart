/// Shares token requests and retries transient registration failures on the next
/// Home/resume sync. Notification permission and FCM registration are separate.
class PushTokenRegistration {
  PushTokenRegistration({
    required this.getToken,
    required this.onToken,
    required this.onFailure,
    DateTime Function()? clock,
    this.timeout = const Duration(seconds: 8),
    this.retryDelay = const Duration(seconds: 30),
  }) : clock = clock ?? DateTime.now;

  final Future<String?> Function() getToken;
  final void Function(String) onToken;
  final void Function() onFailure;
  final DateTime Function() clock;
  final Duration timeout;
  final Duration retryDelay;
  Future<void>? _pending;
  DateTime? _lastAttempt;
  String? _token;
  int _generation = 0;

  void acceptToken(String token) {
    if (token.isEmpty) return;
    _generation++;
    _token = token;
    onToken(token);
  }

  Future<void> ensureToken() {
    if (_token != null) return Future.value();
    if (_pending != null) return _pending!;
    if (_lastAttempt != null &&
        clock().difference(_lastAttempt!) < retryDelay) {
      return Future.value();
    }
    _lastAttempt = clock();
    return _pending = _load().whenComplete(() => _pending = null);
  }

  Future<void> _load() async {
    final generation = _generation;
    try {
      final token = await getToken().timeout(timeout);
      if (generation != _generation) {
        return; // A refresh event supplied a newer token.
      }
      if (token == null || token.isEmpty) {
        onFailure();
      } else {
        acceptToken(token);
      }
    } catch (_) {
      // Never log tokens or raw provider responses. A later sync can retry.
      if (_token == null) onFailure();
    }
  }
}
