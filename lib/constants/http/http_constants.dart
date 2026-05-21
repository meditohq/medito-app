import 'package:flutter/foundation.dart';

/// Toggles "mock mode": a fully self-contained demo environment that runs
/// the app against hardcoded fake data instead of the real backend. This
/// lets contributors (and anyone curious) run the app locally without
/// needing API keys or access to the production/staging services.
///
/// Enabled by building/running with `--dart-define=MOCK_MODE=true`.
///
/// When true, the [HttpApiService] factory returns a [MockHttpApiService]
/// (see lib/mock/), Firebase / Stripe / Meta SDK initialisation is skipped
/// in main.dart, and various services short-circuit to no-ops. See
/// lib/mock/README.md for the full picture.
bool get isMockMode =>
    const String.fromEnvironment('MOCK_MODE', defaultValue: 'false') == 'true';

class EnvConfig {
  final String environment;
  final String contentBaseUrl;
  final String authBaseUrl;
  final String apiKey;
  final String editStatsUrl;
  final String deleteAccountBaseUrl;
  final String donationBaseUrl;
  final String donationToken;
  final String paywallFormUrl;
  final String paywallEnvironment;
  final String facebookAppId;
  final String facebookClientToken;

  const EnvConfig({
    required this.environment,
    required this.contentBaseUrl,
    required this.authBaseUrl,
    required this.apiKey,
    required this.editStatsUrl,
    required this.deleteAccountBaseUrl,
    required this.donationBaseUrl,
    required this.donationToken,
    required this.paywallFormUrl,
    required this.paywallEnvironment,
    required this.facebookAppId,
    required this.facebookClientToken,
  });
}

class ProdEnv extends EnvConfig {
  const ProdEnv({
    required super.environment,
    required super.contentBaseUrl,
    required super.authBaseUrl,
    required super.apiKey,
    required super.editStatsUrl,
    required super.deleteAccountBaseUrl,
    required super.donationBaseUrl,
    required super.donationToken,
    required super.paywallFormUrl,
    required super.paywallEnvironment,
    required super.facebookAppId,
    required super.facebookClientToken,
  });
}

class StagingEnv extends EnvConfig {
  const StagingEnv({
    required super.environment,
    required super.contentBaseUrl,
    required super.authBaseUrl,
    required super.apiKey,
    required super.editStatsUrl,
    required super.deleteAccountBaseUrl,
    required super.donationBaseUrl,
    required super.donationToken,
    required super.paywallFormUrl,
    required super.paywallEnvironment,
    required super.facebookAppId,
    required super.facebookClientToken,
  });
}

const _prodEnv = ProdEnv(
  apiKey: String.fromEnvironment('APP_KEY'),
  environment: String.fromEnvironment('ENVIRONMENT'),
  contentBaseUrl: String.fromEnvironment('CONTENT_BASE_URL'),
  authBaseUrl: String.fromEnvironment('AUTH_URL'),
  editStatsUrl: String.fromEnvironment('EDIT_STATS_URL'),
  deleteAccountBaseUrl: 'https://accounts.medito.app/delete',
  donationBaseUrl: String.fromEnvironment('DONATION_BASE_URL'),
  donationToken: String.fromEnvironment('DONATION_TOKEN'),
  // In-app paywall webview. Override at build time with --dart-define=PAYWALL_URL=...
  // (e.g. http://10.0.2.2:4321/paywall on the Android emulator) to point at a
  // local Astro dev server.
  paywallFormUrl: String.fromEnvironment(
    'PAYWALL_URL',
    defaultValue: 'https://paywall.meditofoundation.org/',
  ),
  paywallEnvironment:
      String.fromEnvironment('PAYWALL_ENV', defaultValue: 'live'),
  facebookAppId: String.fromEnvironment('FACEBOOK_APP_ID'),
  facebookClientToken: String.fromEnvironment('FACEBOOK_CLIENT_TOKEN'),
);

const _stagingEnv = StagingEnv(
  apiKey: String.fromEnvironment('APP_KEY'),
  environment: String.fromEnvironment('ENVIRONMENT'),
  contentBaseUrl: String.fromEnvironment('CONTENT_BASE_URL'),
  authBaseUrl: String.fromEnvironment('AUTH_URL'),
  editStatsUrl: String.fromEnvironment('EDIT_STATS_URL'),
  deleteAccountBaseUrl: 'https://accounts.medito.dev/delete',
  donationBaseUrl: String.fromEnvironment('DONATION_BASE_URL'),
  donationToken: String.fromEnvironment('DONATION_TOKEN'),
  paywallFormUrl: String.fromEnvironment(
    'PAYWALL_URL',
    defaultValue: 'https://test.meditofoundation.org/',
  ),
  paywallEnvironment:
      String.fromEnvironment('PAYWALL_ENV', defaultValue: 'dev'),
  facebookAppId: String.fromEnvironment('FACEBOOK_APP_ID'),
  facebookClientToken: String.fromEnvironment('FACEBOOK_CLIENT_TOKEN'),
);

// Resolve the active env config from the loaded `.prod.json` / `.staging.json`
// rather than the Flutter build mode, so that "debug build with .prod.json"
// (used for local-on-device testing of the prod backend) actually hits prod.
// Falls back to release-mode = prod, debug-mode = staging when ENVIRONMENT is
// unset (e.g. tests, mock mode).
const _envName = String.fromEnvironment('ENVIRONMENT');
EnvConfig get _currentEnv {
  if (_envName == 'production') return _prodEnv;
  if (_envName == 'debug' || _envName == 'staging' || _envName == 'mock') {
    return _stagingEnv;
  }
  return kReleaseMode ? _prodEnv : _stagingEnv;
}

String get apiKey => _currentEnv.apiKey;
String get environment => _currentEnv.environment;
String get contentBaseUrl => _currentEnv.contentBaseUrl;
String get authBaseUrl => _currentEnv.authBaseUrl;
String get editStatsUrl => _currentEnv.editStatsUrl;
String get deleteAccountUrl => _currentEnv.deleteAccountBaseUrl;
String get donationBaseUrl => _currentEnv.donationBaseUrl;
String get donationToken => _currentEnv.donationToken;
String get paywallFormUrl => _currentEnv.paywallFormUrl;
String get paywallEnvironment => _currentEnv.paywallEnvironment;
String get facebookAppId => _currentEnv.facebookAppId;
String get facebookClientToken => _currentEnv.facebookClientToken;

class HTTPConstants {
  //END POINTS
  static const String tokens = 'tokens';
  static const String packs = 'packs';
  static const String tracks = 'tracks';
  static const String favorites = 'favorites';
  static const String backgroundSounds = 'backgroundsounds';
  static const String home = 'home';
  static const String latestAnnouncement = 'announcements?latest=true';
  static const String allStats = 'stats';
  static const String me = 'me';
  static const String searchTracks = 'search/tracks';

  // AUTH END POINTS
  static const String authSignIn = 'signin';
  static const String authOtpRequest = 'otp/request';
  static const String authTokensRefresh = 'tokens/refresh';
  static const String authTokensSignout = 'tokens/signout';

  // MAINTENANCE END POINTS
  static String maintenance = '${contentBaseUrl}maintenance';

  // EVENT END POINTS
  static const String firebaseEvent = '/fcm';
  static const String rate = '/rate';
  static const String donate = 'donations/asks?random=true';

  // STRIPE PAYMENT ENDPOINTS (using donation service)
  static const String paymentConfig = 'config';
  static const String createPaymentIntent = 'payment-intents';
  static const String confirmPaymentIntent = 'payment-intents/confirm';

  // DEAD DOMAINS - domains that no longer exist and should be avoided
  static const List<String> _deadDomains = [
    'images.medito.space',
  ];

  /// Checks if a URL is from a dead/unavailable domain
  static bool isDeadDomain(String url) {
    return _deadDomains.any((domain) => url.contains(domain));
  }
}

// Auth response models
class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final String clientId;
  final String? email;

  AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    String? clientId,
    this.email,
  }) : clientId = clientId ?? '';

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: json['expires_in'] as int,
      clientId: json['client_id'] as String?,
      email: json['email'] as String?,
    );
  }
}

class OtpResponse {
  final bool success;
  final String message;
  final int? expiresIn;
  final bool? rateLimited;
  final int? retryAfter;

  OtpResponse({
    required this.success,
    required this.message,
    this.expiresIn,
    this.rateLimited,
    this.retryAfter,
  });

  factory OtpResponse.fromJson(Map<String, dynamic> json) {
    return OtpResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      expiresIn: json['expires_in'] as int?,
      rateLimited: json['rate_limited'] as bool?,
      retryAfter: json['retry_after'] as int?,
    );
  }
}
