import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/device_info/device_and_app_info_model.dart';
import 'package:medito/services/network/header_service.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:medito/services/notifications/supporter_campaign_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/firebase_test_helper.dart';

class _Messaging extends FirebaseMessagingPlatform {
  final token = Completer<String?>();
  int requests = 0;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  FirebaseMessagingPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseMessagingPlatform setInitialValues({bool? isAutoInitEnabled}) => this;

  @override
  Future<String?> getToken({
    String? vapidKey,
    String? serviceWorkerScriptPath,
  }) {
    requests++;
    return token.future;
  }
}

class _Client extends HttpApiService {
  _Client() : super.internal();
  int syncs = 0;

  @override
  Future<Map<String, dynamic>> postRequest(String path, {dynamic body}) async {
    syncs++;
    return {'assignment': null};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'campaign eligibility sync waits for shared token registration',
    () async {
      await FirebaseTestHelper.initializeFirebaseForTest();
      final messaging = _Messaging();
      FirebaseMessagingPlatform.instance = messaging;
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final headers = HeaderService(
        const DeviceAndAppInfoModel(
          model: 'test',
          os: 'test',
          platform: 'android',
          buildNumber: '1',
          appVersion: '2611.15.0',
          languageCode: 'en',
          currencyName: 'USD',
        ),
      );
      final client = _Client();
      final api = SupporterCampaignApi(client);
      final startup = headers.initialise();
      final sync = api.sync(prefs, permissionGranted: true);
      await Future<void>.delayed(Duration.zero);
      expect(messaging.requests, 1);
      expect(client.syncs, 0);
      messaging.token.complete('registered-before-sync');
      await Future.wait([startup, sync]);
      expect(client.syncs, 1);
      await api.sync(prefs, permissionGranted: true);
      expect(messaging.requests, 1);
    },
  );
}
