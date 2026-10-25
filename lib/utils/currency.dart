import 'package:intl/intl.dart';

/// Stripe zero-decimal currencies: the integer amount is already in whole units,
/// not hundredths.
///
/// A Stripe amount carries no record of which kind of currency it belongs to, so
/// `amount / 100` is only correct for the currencies *not* in this set. Applied
/// to ¥1000 it yields 10.00, understating the figure a hundredfold — which on a
/// payment sheet means showing someone a different price than they are charged.
const zeroDecimalCurrencies = {
  'bif',
  'clp',
  'djf',
  'gnf',
  'jpy',
  'kmf',
  'krw',
  'mga',
  'pyg',
  'rwf',
  'ugx',
  'vnd',
  'vuv',
  'xaf',
  'xof',
  'xpf',
};

bool isZeroDecimalCurrency(String currency) =>
    zeroDecimalCurrencies.contains(currency.trim().toLowerCase());

/// How many minor-unit digits Stripe sends for [currency] — the single source
/// of truth for every conversion below, so they cannot drift apart.
///
/// Stripe only has 0-, 2- and 3-decimal currencies. Intl knows the 3-decimal
/// ones (KWD, BHD, JOD, OMR, TND — thousandths, not hundredths), but its data
/// is ISO-based and disagrees with Stripe on ISK: Iceland dropped the aurar, so
/// Intl reports 0 digits, while Stripe still sends ISK in hundredths. Trusting
/// Intl there would overstate every ISK amount a hundredfold. Hence
/// [zeroDecimalCurrencies] decides the 0 case and Intl only picks between 2
/// and 3.
int minorUnitDigits(String currency) {
  if (isZeroDecimalCurrency(currency)) return 0;
  final code = currency.trim().toUpperCase();
  // Unknown codes fall back to 2 rather than throwing.
  final digits = NumberFormat.simpleCurrency(name: code).decimalDigits ?? 2;

  return digits < 2 ? 2 : digits;
}

/// The amount in major units — ¥1000 stays 1000, $10.00 becomes 10.0.
double currencyAmountToUnits(int amount, String currency) {
  var divisor = 1;
  for (var i = 0; i < minorUnitDigits(currency); i++) {
    divisor *= 10;
  }

  return amount / divisor;
}

/// Plain numeric string in major units, no symbol and no grouping separators.
///
/// For places that need the bare number because something else supplies the
/// currency: Apple Pay's `ApplePayCartSummaryItem.amount`, and localized strings
/// that take the amount and the currency code as separate placeholders.
String currencyAmountToUnitsString(int amount, String currency) =>
    currencyAmountToUnits(
      amount,
      currency,
    ).toStringAsFixed(minorUnitDigits(currency));

/// Human-readable amount with its currency symbol, e.g. `¥1,000` or `$10.50`.
String formatCurrencyAmount(int amount, String currency) {
  final code = currency.trim().toLowerCase();
  final value = currencyAmountToUnits(amount, code);
  final wholeNumber = value == value.roundToDouble();
  final format = NumberFormat.simpleCurrency(
    name: code.toUpperCase(),
    // A round amount reads better without trailing zeros ($10, not $10.00).
    decimalDigits: wholeNumber ? 0 : minorUnitDigits(code),
  );

  return format.format(value);
}

/// Symbols that several currencies print the same way, mapped to the one
/// currency a listener would assume. Screen readers say "$5" as "5 dollars"
/// whether it's US, Canadian or Colombian pesos.
const _ambiguousSymbolDefaults = {r'$': 'USD', '¥': 'JPY'};

/// [formatCurrencyAmount] for screen readers: where the symbol is shared by
/// several currencies (`$` for CAD/AUD/MXN/COP/CLP/UYU…, `¥` for CNY), it is
/// swapped for the ISO code, e.g. `COP 20,000`. Every other amount is returned
/// exactly as displayed.
String spokenCurrencyAmount(int amount, String currency) {
  final visible = formatCurrencyAmount(amount, currency);
  final code = currency.trim().toUpperCase();
  final symbol = NumberFormat.simpleCurrency(name: code).currencySymbol;
  final assumed = _ambiguousSymbolDefaults[symbol];
  if (assumed == null || assumed == code) return visible;

  final at = visible.indexOf(symbol);
  if (at < 0) return visible;
  final before = visible.substring(0, at);
  final after = visible.substring(at + symbol.length);
  // "$5" has no gap between symbol and number; "COP5" would be read as one
  // word, so add a non-breaking space when the number follows directly.
  final gap = after.isNotEmpty && RegExp(r'^\d').hasMatch(after)
      ? ' '
      : '';
  return '$before$code$gap$after';
}
