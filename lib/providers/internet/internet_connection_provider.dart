import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

class ConnectionState {
  final InternetConnectionStatus status;
  final bool shouldShowMessage;

  ConnectionState(this.status, {this.shouldShowMessage = false});
}

class ConnectionNotifier extends AsyncNotifier<ConnectionState> {
  Timer? _debounceTimer;
  bool _isFirstCheck = true;

  @override
  Future<ConnectionState> build() async {
    final status = await InternetConnectionChecker.instance.connectionStatus;
    ref.onDispose(() {
      _debounceTimer?.cancel();
    });

    // Listen to connection changes
    InternetConnectionChecker.instance.onStatusChange
        .listen(_handleStatusChange);

    return ConnectionState(status, shouldShowMessage: false);
  }

  void _handleStatusChange(InternetConnectionStatus status) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      if (_isFirstCheck) {
        _isFirstCheck = false;
        state = AsyncData(ConnectionState(status, shouldShowMessage: false));
        return;
      }
      state = AsyncData(ConnectionState(status, shouldShowMessage: true));
    });
  }
}

final connectionNotifierProvider =
    AsyncNotifierProvider<ConnectionNotifier, ConnectionState>(() {
  return ConnectionNotifier();
});
