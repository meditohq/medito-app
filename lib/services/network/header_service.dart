import 'dart:async';

import '../../utils/logger.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/models/models.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:medito/services/notifications/push_token_registration.dart';
import 'package:medito/services/notifications/supporter_campaign_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HeaderService {
  DeviceAndAppInfoModel _deviceInfo;
  String? _fcmToken;
  final _httpApiService = HttpApiService();
  static HeaderService? _active;
  StreamSubscription<String>? _tokenSubscription;
  late final PushTokenRegistration _registration;

  HeaderService(this._deviceInfo) {
    _active?._tokenSubscription?.cancel();
    _active = this;
    _registration = PushTokenRegistration(
      getToken: () => FirebaseMessaging.instance.getToken(),
      onToken: (token) {
        _fcmToken = token;
        _updateHeaders();
      },
      onFailure: () => AppLogger.w(
        'HEADER',
        'Push token unavailable; registration will retry on Home/resume sync',
      ),
    );
    _initFcmTokenListener();
  }

  /// Retry a failed startup registration before syncing campaign eligibility.
  /// Does not request OS permission or delete an existing Firebase token.
  static Future<void> ensurePushToken() async {
    if (!isMockMode) await _active?._registration.ensureToken();
  }

  void _initFcmTokenListener() {
    if (isMockMode) return;
    _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((
      fcmToken,
    ) {
      _registration.acceptToken(fcmToken);
      unawaited(_syncCampaignPreferences());
    });
  }

  Future<void> _syncCampaignPreferences() async {
    try {
      await SupporterCampaignApi.updatePreferences(
        await SharedPreferences.getInstance(),
      );
    } catch (_) {
      // Home/resume sync retries without disrupting token/header registration.
    }
  }

  Future<void> initialise() async {
    if (isMockMode) {
      _updateHeaders();
      return;
    }
    await _registration.ensureToken();
    _updateHeaders();
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
