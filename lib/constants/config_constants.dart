class ConfigConstants {
  // Pack IDs
  static const String basicsPackId = 'j4SVy5TrKAT7ywxp';

  // URL constants
  static const String meditoUrl = 'https://meditofoundation.org/';
  static const String donationFormUrl = 'https://donate.meditofoundation.org';
  // The in-app paywall webview URL is environment-specific and lives on
  // EnvConfig — see `paywallFormUrl` getter in lib/constants/http/http_constants.dart.
  static const String donationPortalUrl = 'https://bit.ly/3yFqVbM';
  static const String contactFormBaseUrl = 'https://tally.so/r/wLGBaO';
  static const String dontKillMyAppUrl = 'https://dontkillmyapp.com';
  static const String shopUrl = 'https://shop.medito.app';

  // Technical constants for device info and debugging
  static const String id = 'id';
  static const String env = 'env';
  static const String email = 'email';
  static const String appVersion = 'appVersion';
  static const String deviceModel = 'deviceModel';
  static const String deviceOs = 'deviceOs';
  static const String devicePlatform = 'devicePlatform';
  static const String buildNumber = 'buildNumber';

  // Donation service related strings
  static const String donationInitiatedEvent = 'donation_initiated';

  // Paywall action names for monthly donations
  static const String monthly1 = 'monthly_1';
  static const String monthly2 = 'monthly_2';
  static const String monthly3 = 'monthly_3';
  static const String monthly4 = 'monthly_4';
  static const String monthly5 = 'monthly_5';
  static const String monthlySuggested = 'monthly_suggested';

  // Paywall action names for one-time donations
  static const String onetime1 = 'onetime_1';
  static const String onetime2 = 'onetime_2';
  static const String onetime3 = 'onetime_3';
  static const String onetime4 = 'onetime_4';
  static const String onetime5 = 'onetime_5';
  static const String onetimeSuggested = 'one_time_suggested';

  // Paywall action names for yearly donations
  static const String yearly1 = 'yearly_1';
  static const String yearly2 = 'yearly_2';
  static const String yearly3 = 'yearly_3';
  static const String yearly4 = 'yearly_4';
  static const String yearly5 = 'yearly_5';
  static const String yearlySuggested = 'yearly_suggested';

  // Pricing attribute keys (passed to the paywall webview as query params).
  static const String currency = 'currency';
  static const String currencySymbol = 'currency_symbol';
  static const String pricingCountry = 'pricing_country';
}
