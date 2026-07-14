import '../../utils/logger.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/models/models.dart';
import 'package:medito/services/network/http_api_service.dart';

class HeaderService {
  DeviceAndAppInfoModel _deviceInfo;
  String? _fcmToken;
  final _httpApiService = HttpApiService();

  HeaderService(this._deviceInfo) {
    _initFcmTokenListener();
  }

  void _initFcmTokenListener() {
    if (isMockMode) return;
    FirebaseMessaging.instance.onTokenRefresh.listen((fcmToken) {
      _fcmToken = fcmToken;
      _updateHeaders();
    });
  }

  Future<void> initialise() async {
    if (isMockMode) {
      _updateHeaders();
      return;
    }
    try {
      // getToken can hang indefinitely on iOS when the device is offline
      // (the SDK waits for an APNS token that never arrives). This runs in
      // the splash screen's critical path, so bound it — app launch must
      // never depend on push registration. The onTokenRefresh listener
      // picks the token up later once connectivity returns.
      _fcmToken = await FirebaseMessaging.instance.getToken().timeout(
        const Duration(seconds: 8),
      );
      if (_fcmToken == null) {
        // Force token creation if it's null
        await FirebaseMessaging.instance.deleteToken().timeout(
          const Duration(seconds: 5),
        );
        _fcmToken = await FirebaseMessaging.instance.getToken().timeout(
          const Duration(seconds: 5),
        );
      }
    } catch (e) {
      // Handle error but continue execution
      AppLogger.e('HEADER', 'Error getting FCM token: $e');
    } finally {
      _updateHeaders();
    }
  }

  /// Update the device info and refresh headers
  /// This is useful when the language changes
  void updateDeviceInfo(DeviceAndAppInfoModel newDeviceInfo) {
    _deviceInfo = newDeviceInfo;
    _updateHeaders();
    AppLogger.i(
      'HEADER',
      'Device info updated, headers refreshed. Language: ${_deviceInfo.languageCode}',
    );
  }

  void _updateHeaders() {
    var customHeaders = _createCustomHeaders();
    _httpApiService.addDeviceHeaders(customHeaders);
  }

  Map<String, String> _createCustomHeaders() => {
    'device-os': _deviceInfo.os,
    'device-language': _deviceInfo.languageCode,
    'device-model': _deviceInfo.model,
    'app-version': _deviceInfo.appVersion,
    'device-time': '${DateTime.now()}',
    'device-platform': _deviceInfo.platform,
    'fcmt': ?_fcmToken,
    'currency-name': _deviceInfo.currencyName,
  };
}
