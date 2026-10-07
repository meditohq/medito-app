import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/services/analytics/play_install_referrer_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('utmsFromReferrer', () {
    Map<String, String> parse(String r) =>
        PlayInstallReferrerService.utmsFromReferrer(r);

    test('keeps UTMs from the referrer', () {
      expect(
        parse(
          'utm_source=google&utm_medium=cpc&utm_campaign=OWA_App%20Install_Android_US_Sept19',
        ),
        {
          'utm_source': 'google',
          'utm_medium': 'cpc',
          'utm_campaign': 'OWA_App Install_Android_US_Sept19',
        },
      );
    });

    test('drops Meta\'s encrypted utm_content but keeps the source', () {
      final blob = Uri.encodeQueryComponent(
        '{"app":0,"t":1759000000,"source":{"data":"${'a' * 300}","nonce":"b"}}',
      );
      expect(
        parse(
          'utm_source=apps.facebook.com&utm_campaign=fb4a&utm_content=$blob',
        ),
        {'utm_source': 'apps.facebook.com', 'utm_campaign': 'fb4a'},
      );
    });

    test('a Google click ID alone means Google Ads', () {
      expect(parse('gclid=Cj0KCQjw&gbraid=0AAAAA'), {
        'utm_source': 'google',
        'utm_medium': 'cpc',
      });
    });

    test('organic Play installs are kept as such', () {
      expect(parse('utm_source=google-play&utm_medium=organic'), {
        'utm_source': 'google-play',
        'utm_medium': 'organic',
      });
    });

    test('empty or malformed referrers give nothing', () {
      expect(parse(''), isEmpty);
      expect(parse('utm_source=%E0%A4%A'), isEmpty);
      expect(parse('foo=bar'), isEmpty);
    });
  });

  group('attributeOnce', () {
    late int calls;
    late Object? Function() reply;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(PlayInstallReferrerService.channel, (
            call,
          ) async {
            calls++;
            return reply();
          });
    });

    Future<SharedPreferences> prefs() => SharedPreferences.getInstance();
    final service = PlayInstallReferrerService(isAndroid: true);

    test('stores the install source and runs once', () async {
      reply = () => 'utm_source=apps.facebook.com&utm_campaign=fb4a';
      await service.attributeOnce();
      await service.attributeOnce();

      expect(calls, 1);
      expect(
        (await prefs()).getString(SharedPreferenceConstants.utmSource),
        'apps.facebook.com',
      );
    });

    test('keeps UTMs a deep link already stored', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferenceConstants.utmSource: 'fb',
        SharedPreferenceConstants.utmCampaign: '120245936809960777',
      });
      reply = () => 'utm_source=apps.facebook.com&utm_campaign=fb4a';
      await service.attributeOnce();

      final p = await prefs();
      expect(p.getString(SharedPreferenceConstants.utmSource), 'fb');
      expect(
        p.getString(SharedPreferenceConstants.utmCampaign),
        '120245936809960777',
      );
    });

    test('an unavailable Play service is retried next launch', () async {
      reply = () => throw PlatformException(code: 'unavailable');
      await service.attributeOnce();
      reply = () => 'gclid=abc';
      await service.attributeOnce();

      expect(calls, 2);
      expect(
        (await prefs()).getString(SharedPreferenceConstants.utmSource),
        'google',
      );
    });

    test('no referrer (sideload) is final', () async {
      reply = () => '';
      await service.attributeOnce();
      await service.attributeOnce();

      expect(calls, 1);
      expect(
        (await prefs()).getString(SharedPreferenceConstants.utmSource),
        isNull,
      );
    });

    test('does nothing off Android', () async {
      reply = () => 'gclid=abc';
      await PlayInstallReferrerService(isAndroid: false).attributeOnce();
      expect(calls, 0);
    });
  });
}
