import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/stripe/paywall_config_model.dart';

void main() {
  Map<String, Object?> baseJson() => {
    'publishableKey': 'pk_test_123',
    'merchantIdentifier': 'merchant.medito',
    'merchantName': 'Medito',
    'countryCode': 'US',
    'currencyCode': 'usd',
    'supportedNetworks': ['visa', 'mastercard'],
    'pricing': {
      'oneTime': [500, 1000, 2000],
      'monthly': [500, 1000, 2000],
      'yearly': [5000, 10000, 20000],
      'currency': 'usd',
      'country': 'US',
      'suggested': {'oneTime': 1000, 'monthly': 1000, 'yearly': 10000},
    },
    'email': 'donor@example.com',
  };

  group('PaywallConfigModel', () {
    test('parses a full response with an experiment', () {
      final json = baseJson()
        ..['experiment'] = {
          'id': 'donate6',
          'variant': 'B',
          'config': {
            'nativePaywall': true,
            'monthly': [300, 600, 1200],
            'suggested': {'monthly': 600},
            'heroCopy': {
              'eyebrow': 'Help keep Medito free',
              'heading': 'Keep meditation free<br /><em>for everyone</em>',
              'subcopy': 'Funded entirely by donors like you.',
            },
          },
        };

      final model = PaywallConfigModel.fromJson(json);

      expect(model.publishableKey, 'pk_test_123');
      expect(model.email, 'donor@example.com');
      expect(model.experiment?.id, 'donate6');
      expect(model.experiment?.variant, 'B');
      expect(model.nativePaywallEnabled, isTrue);
      expect(model.effectiveLadder('monthly'), [300, 600, 1200]);
      expect(model.effectiveSuggested('monthly'), 600);
      // Experiment declares ladders → undeclared frequencies are not offered.
      expect(model.isFrequencyOffered('monthly'), isTrue);
      expect(model.isFrequencyOffered('oneTime'), isFalse);
      expect(model.isFrequencyOffered('yearly'), isFalse);
      // HTML is stripped, <br> becomes a newline.
      expect(model.heroHeading, 'Keep meditation free\nfor everyone');
      expect(model.heroSubcopy, 'Funded entirely by donors like you.');
    });

    test('parses with null experiment and defaults, falls back to pricing', () {
      final model = PaywallConfigModel.fromJson(baseJson());

      expect(model.experiment, isNull);
      expect(model.defaults, isNull);
      expect(model.nativePaywallEnabled, isFalse);
      expect(model.effectiveLadder('oneTime'), [500, 1000, 2000]);
      expect(model.effectiveSuggested('yearly'), 10000);
      expect(model.isFrequencyOffered('oneTime'), isTrue);
      expect(model.isFrequencyOffered('monthly'), isTrue);
      expect(model.isFrequencyOffered('yearly'), isTrue);
      expect(model.heroEyebrow, isNull);
    });

    test('applies source ladder overrides over the effective config', () {
      final json = baseJson()
        ..['experiment'] = {
          'id': 'donate6',
          'variant': 'A',
          'config': {
            'monthly': [500, 1000],
            'sources': {
              'onboarding': {
                'monthly': [100, 200, 400],
                'oneTime': [300],
                'suggested': {'monthly': 200},
              },
            },
          },
        };

      final model = PaywallConfigModel.fromJson(json);

      expect(
        model.effectiveLadder('monthly', source: 'onboarding'),
        [100, 200, 400],
      );
      expect(model.effectiveLadder('monthly'), [500, 1000]);
      expect(model.effectiveSuggested('monthly', source: 'onboarding'), 200);
      // Source override arrays count as experiment-declared frequencies.
      expect(model.isFrequencyOffered('oneTime', source: 'onboarding'), isTrue);
      expect(model.isFrequencyOffered('yearly', source: 'onboarding'), isFalse);
    });

    test('ignores unknown fields', () {
      final json = baseJson()
        ..['someFutureField'] = {'nested': true}
        ..['anotherOne'] = 42
        ..['experiment'] = {
          'id': 'donate7',
          'variant': 'A',
          'config': {'unknownKnob': 'x'},
          'unexpected': [1, 2, 3],
        };

      final model = PaywallConfigModel.fromJson(json);

      expect(model.experiment?.id, 'donate7');
      expect(model.nativePaywallEnabled, isFalse);
      expect(model.effectiveLadder('monthly'), [500, 1000, 2000]);
    });
  });
}
