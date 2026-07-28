import 'package:intl/intl.dart';

/// Stripe zero-decimal currencies: the integer amount is already in whole units,
/// not hundredths.
///
/// A Stripe amount carries no record of which kind of currency it belongs to, so
/// `amount / 100` is only correct for the currencies *not* in this set. Applied
/// to ¥1000 it yields 10.00, understating the figure a hundredfold — which on a
/// payment sheet means showing someone a different price than they are charged.
const zeroDecimalCurrencies = {
  'bif', 'clp', 'djf', 'gnf', 'jpy', 'kmf', 'krw', 'mga',
  'pyg', 'rwf', 'ugx', 'vnd', 'vuv', 'xaf', 'xof', 'xpf',
};

bool isZeroDecimalCurrency(String currency) =>
    zeroDecimalCurrencies.contains(currency.trim().toLowerCase());

/// The amount in major units — ¥1000 stays 1000, $10.00 becomes 10.0.
double currencyAmountToUnits(int amount, String currency) {
  final code = currency.trim().toUpperCase();
  final digits = NumberFormat.simpleCurrency(name: code).decimalDigits ?? 2;

  var divisor = 1;
  for (var i = 0; i < digits; i++) {
    divisor *= 10;
  }

  return amount / divisor;
}

/// Plain numeric string in major units, no symbol and no grouping separators.
///
/// For places that need the bare number because something else supplies the
/// currency: Apple Pay's `ApplePayCartSummaryItem.amount`, and localized strings
/// that take the amount and the currency code as separate placeholders.
String currencyAmountToUnitsString(int amount, String currency) {
  final zeroDecimal = isZeroDecimalCurrency(currency);
  final value = currencyAmountToUnits(amount, currency);
  return zeroDecimal ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
}

/// Human-readable amount with its currency symbol, e.g. `¥1,000` or `$10.50`.
String formatCurrencyAmount(int amount, String currency) {
  final code = currency.trim().toLowerCase();
  final zeroDecimal = isZeroDecimalCurrency(code);
  final value = currencyAmountToUnits(amount, code);
  final wholeNumber = value == value.roundToDouble();
  final format = NumberFormat.simpleCurrency(
    name: code.toUpperCase(),
    decimalDigits: (zeroDecimal || wholeNumber) ? 0 : 2,
  );

  return format.format(value);
}
