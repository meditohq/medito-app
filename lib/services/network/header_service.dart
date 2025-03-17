import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:medito/models/models.dart';
import 'package:medito/services/network/http_api_service.dart';

class HeaderService {
  final DeviceAndAppInfoModel deviceInfo;
  String? _fcmToken;

  HeaderService(this.deviceInfo) {
    _initFcmTokenListener();
  }

  void _initFcmTokenListener() {
    FirebaseMessaging.instance.onTokenRefresh.listen((fcmToken) {
      _fcmToken = fcmToken;
      _updateHeaders();
    });
  }
  Future<void> initialise() async {
    try {
      _fcmToken = await FirebaseMessaging.instance.getToken();
      if (_fcmToken == null) {
        // Force token creation if it's null
        await FirebaseMessaging.instance.deleteToken();
        _fcmToken = await FirebaseMessaging.instance.getToken();
      }
    } catch (e) {
      // Handle error but continue execution
      print('Error getting FCM token: $e');
    } finally {
      _updateHeaders();
    }
  }

  void _updateHeaders() {
    var customHeaders = _createCustomHeaders();
    HttpApiService().addDeviceHeaders(customHeaders);
  }

  Map<String, String> _createCustomHeaders() {
    return {
      'device-os': deviceInfo.os,
      'device-language': deviceInfo.languageCode,
      'device-model': deviceInfo.model,
      'app-version': deviceInfo.appVersion,
      'device-time': '${DateTime.now()}',
      'device-platform': deviceInfo.platform,
      if (_fcmToken != null) 'fcmt': _fcmToken!,
      'currency-name': deviceInfo.currencyName,
    };
  }
}
