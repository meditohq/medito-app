import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:medito/utils/currency.dart';

void main() {
  final previousLocale = Intl.getCurrentLocale();
  setUpAll(() => Intl.defaultLocale = 'en_US');
  tearDownAll(() => Intl.defaultLocale = previousLocale);

  group('isZeroDecimalCurrency', () {
    test('identifies zero-decimal currencies regardless of case or padding', () {
      expect(isZeroDecimalCurrency('jpy'), isTrue);
      expect(isZeroDecimalCurrency('JPY'), isTrue);
      expect(isZeroDecimalCurrency(' krw '), isTrue);
      expect(isZeroDecimalCurrency('usd'), isFalse);
      expect(isZeroDecimalCurrency('ngn'), isFalse);
    });
  });

  group('currencyAmountToUnitsString', () {
    test('divides decimal currencies by 100', () {
      expect(currencyAmountToUnitsString(1000, 'usd'), '10.00');
      expect(currencyAmountToUnitsString(70000, 'ngn'), '700.00');
      expect(currencyAmountToUnitsString(1050, 'eur'), '10.50');
    });

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
}
