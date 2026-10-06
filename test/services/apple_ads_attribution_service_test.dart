import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/services/analytics/apple_ads_attribution_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<int> statuses;
  late List<Map<String, Object>> events;
  late int requests;
  String? token;

  const attributed = {
    'attribution': true,
    'orgId': 40669820,
    'campaignId': 2142684159,
    'conversionType': 'Download',
    'claimType': 'Click',
    'adGroupId': 2142680001,
    'countryOrRegion': 'US',
    'keywordId': 2142680002,
    'adId': 2142680003,
  };

  AppleAdsAttributionService service(Map<String, Object?> body) =>
      AppleAdsAttributionService(
        isIOS: true,
        retryDelay: Duration.zero,
        logEvent: (name, params) async => events.add(params),
        client: MockClient((request) async {
          requests++;
          expect(request.body, token);
          final status = statuses.isEmpty ? 200 : statuses.removeAt(0);
          return http.Response(status == 200 ? jsonEncode(body) : '', status);
        }),
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    statuses = [];
    events = [];
    requests = 0;
    token = 'token-abc';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          AppleAdsAttributionService.channel,
          (call) async => token,
        );
  });

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  test('attributed install stores Apple Ads UTMs and logs the IDs', () async {
    await service(attributed).attributeOnce();

    final p = await prefs();
    expect(p.getString(SharedPreferenceConstants.utmSource), 'apple-search');
    expect(p.getString(SharedPreferenceConstants.utmMedium), 'asa');
    expect(p.getString(SharedPreferenceConstants.utmCampaign), '2142684159');
    expect(p.getString(SharedPreferenceConstants.utmContent), '2142680001');
    expect(p.getString(SharedPreferenceConstants.utmTerm), '2142680002');
    expect(events.single, {
      'attributed': 'true',
      'campaign_id': '2142684159',
      'ad_group_id': '2142680001',
      'keyword_id': '2142680002',
      'claim_type': 'Click',
      'conversion_type': 'Download',
      'country_or_region': 'US',
    });
  });

  test('runs once per install', () async {
    await service(attributed).attributeOnce();
    await service(attributed).attributeOnce();
    expect(requests, 1);
  });

  test('non-attributed install logs false and stores no UTMs', () async {
    await service({'attribution': false}).attributeOnce();

    expect(events.single, {'attributed': 'false'});
    expect(
      (await prefs()).getString(SharedPreferenceConstants.utmSource),
      isNull,
    );
  });

  test('keeps UTMs a deep link already stored', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferenceConstants.utmSource: 'apple-search',
      SharedPreferenceConstants.utmCampaign: 'discovery',
    });
    await service(attributed).attributeOnce();

    final p = await prefs();
    expect(p.getString(SharedPreferenceConstants.utmCampaign), 'discovery');
    expect(events.single['campaign_id'], '2142684159');
  });

  test('retries a 404 until the record is ready', () async {
    statuses = [404, 404];
    await service(attributed).attributeOnce();
    expect(requests, 3);
    expect(events, hasLength(1));
  });

  test('server error or exhausted 404s retry on the next launch', () async {
    statuses = [500];
    await service(attributed).attributeOnce();
    statuses = [404, 404, 404, 404];
    await service(attributed).attributeOnce();
    expect(events, isEmpty);

    await service(attributed).attributeOnce();
    expect(events, hasLength(1));
  });

  test('rejected token is not retried', () async {
    statuses = [400];
    await service(attributed).attributeOnce();
    await service(attributed).attributeOnce();
    expect(requests, 1);
    expect(events, isEmpty);
  });

  test('ignores the sample payload from non-App Store builds', () async {
    await service({...attributed, 'campaignId': 1234567890}).attributeOnce();

    expect(events, isEmpty);
    expect(
      (await prefs()).getString(SharedPreferenceConstants.utmSource),
      isNull,
    );
  });

  test('no token (e.g. channel failure) does nothing yet', () async {
    token = null;
    await service(attributed).attributeOnce();
    expect(requests, 0);
    expect(
      (await prefs()).getBool(
        SharedPreferenceConstants.appleAdsAttributionChecked,
      ),
      isNull,
    );
  });

  test('does nothing off iOS', () async {
    await AppleAdsAttributionService(
      isIOS: false,
      client: MockClient((_) async => fail('no request expected')),
    ).attributeOnce();
  });
}
