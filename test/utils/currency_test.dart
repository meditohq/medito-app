import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:medito/utils/currency.dart';

void main() {
  final previousLocale = Intl.getCurrentLocale();
  setUpAll(() => Intl.defaultLocale = 'en_US');
  tearDownAll(() => Intl.defaultLocale = previousLocale);

  group('isZeroDecimalCurrency', () {
    test(
      'identifies zero-decimal currencies regardless of case or padding',
      () {
        expect(isZeroDecimalCurrency('jpy'), isTrue);
        expect(isZeroDecimalCurrency('JPY'), isTrue);
        expect(isZeroDecimalCurrency(' krw '), isTrue);
        expect(isZeroDecimalCurrency('usd'), isFalse);
        expect(isZeroDecimalCurrency('ngn'), isFalse);
      },
    );
  });

  group('minorUnitDigits', () {
    test('takes three-decimal currencies from Intl', () {
      for (final code in ['kwd', 'bhd', 'jod', 'omr', 'tnd']) {
        expect(minorUnitDigits(code), 3, reason: code);
      }
    });

    test('keeps Stripe as the authority where Intl disagrees', () {
      // Iceland dropped the aurar so Intl reports 0 digits, but Stripe still
      // sends ISK in hundredths — trusting Intl would overstate it 100x.
      expect(minorUnitDigits('isk'), 2);
      expect(minorUnitDigits('ISK'), 2);
    });

    test('uses the Stripe set for zero-decimal currencies', () {
      for (final code in zeroDecimalCurrencies) {
        expect(minorUnitDigits(code), 0, reason: code);
      }
    });

    test('falls back to two digits for unknown codes', () {
      expect(minorUnitDigits('zzz'), 2);
      expect(minorUnitDigits(''), 2);
    });
  });

  group('currencyAmountToUnitsString', () {
    test(
      'divides non-zero-decimal currencies by their minor unit exponent',
      () {
        expect(currencyAmountToUnitsString(1000, 'usd'), '10.00');
        expect(currencyAmountToUnitsString(1050, 'eur'), '10.50');
        expect(currencyAmountToUnitsString(1050, 'kwd'), '1.050');
        expect(currencyAmountToUnitsString(70000, 'ngn'), '700.00');
        expect(currencyAmountToUnitsString(1000, 'isk'), '10.00');
      },
    );

    test('leaves zero-decimal amounts as whole units', () {
      // The bug this exists to prevent: /100 would put "10.00" on an Apple Pay
      // sheet for a ¥1000 charge, and thank a ₩50,000 donor for ₩500.
      expect(currencyAmountToUnitsString(1000, 'jpy'), '1000');
      expect(currencyAmountToUnitsString(50000, 'krw'), '50000');
      expect(currencyAmountToUnitsString(5000, 'vnd'), '5000');
    });

    test('emits no grouping separators, which Apple Pay would reject', () {
      expect(currencyAmountToUnitsString(1234567, 'usd'), '12345.67');
      expect(currencyAmountToUnitsString(1234567, 'jpy'), '1234567');
    });
  });

  group('formatCurrencyAmount', () {
    test('formats zero-decimal currencies without decimal places', () {
      expect(formatCurrencyAmount(1000, 'jpy'), '¥1,000');
    });

    test('shows cents only when the amount has them', () {
      expect(formatCurrencyAmount(1050, 'usd'), r'$10.50');
      expect(formatCurrencyAmount(1000, 'usd'), r'$10');
    });
  });

  group('spokenCurrencyAmount', () {
    test('names the currency where its symbol is shared', () {
      // All of these print as a bare "$", which screen readers say as dollars.
      expect(spokenCurrencyAmount(2000000, 'cop'), 'COP\u00a020,000');
      expect(spokenCurrencyAmount(500, 'cad'), 'CAD\u00a05');
      expect(spokenCurrencyAmount(550, 'aud'), 'AUD\u00a05.50');
      expect(spokenCurrencyAmount(5000, 'clp'), 'CLP\u00a05,000');
      expect(spokenCurrencyAmount(10000, 'MXN'), 'MXN\u00a0100');
      expect(spokenCurrencyAmount(20000, 'uyu'), 'UYU\u00a0200');
      expect(spokenCurrencyAmount(1000, 'cny'), 'CNY\u00a010');
    });

    test('keeps the visible form where the symbol is unambiguous', () {
      expect(spokenCurrencyAmount(500, 'usd'), r'$5');
      expect(spokenCurrencyAmount(1000, 'jpy'), '¥1,000');
      expect(spokenCurrencyAmount(500, 'eur'), '€5');
      expect(spokenCurrencyAmount(500, 'gbp'), '£5');
      expect(spokenCurrencyAmount(500, 'brl'), r'R$5');
      expect(spokenCurrencyAmount(500, 'twd'), r'NT$5');
    });

    test('puts the code where the locale puts the symbol', () {
      Intl.defaultLocale = 'de';
      addTearDown(() => Intl.defaultLocale = 'en_US');
      expect(formatCurrencyAmount(500, 'cad'), '5\u00a0\$');
      expect(spokenCurrencyAmount(500, 'cad'), '5\u00a0CAD');
    });
  });
}
