import 'package:connectivity/connectivity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityStatusProvider = StateNotifierProvider((ref) {
  return ConnectivityStatusNotifier();
});

//ignore: prefer-match-file-name
enum ConnectivityStatus { NotDetermined, isConnected, isDisonnected }

class ConnectivityStatusNotifier extends StateNotifier<ConnectivityStatus> {
  ConnectivityStatusNotifier() : super(ConnectivityStatus.isConnected) {
    checkConnectivity();
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      _setConnectivityStatus(result);
    });
  }

  Future<void> checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    _setConnectivityStatus(connectivityResult);
  }

  void _setConnectivityStatus(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.mobile:
      case ConnectivityResult.wifi:
        state = ConnectivityStatus.isConnected;
        break;
      case ConnectivityResult.none:
        state = ConnectivityStatus.isDisonnected;
        break;
    }
  }
}
