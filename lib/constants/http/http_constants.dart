import 'package:flutter/foundation.dart';

class EnvConfig {
  final String environment;
  final String contentBaseUrl;
  final String authBaseUrl;
  final String apiKey;
  final String editStatsUrl;
  final String deleteAccountBaseUrl;
  final String donationBaseUrl;
  final String donationToken;
  final String superwallApiKey;
  final String paywallEnvironment;
  final String tiktokAndroidAppId;
  final String tiktokIosAppId;

  const EnvConfig({
    required this.environment,
    required this.contentBaseUrl,
    required this.authBaseUrl,
    required this.apiKey,
    required this.editStatsUrl,
    required this.deleteAccountBaseUrl,
    required this.donationBaseUrl,
    required this.donationToken,
    required this.superwallApiKey,
    required this.paywallEnvironment,
    required this.tiktokAndroidAppId,
    required this.tiktokIosAppId,
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
    required super.superwallApiKey,
    required super.paywallEnvironment,
    required super.tiktokAndroidAppId,
    required super.tiktokIosAppId,
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
    required super.superwallApiKey,
    required super.paywallEnvironment,
    required super.tiktokAndroidAppId,
    required super.tiktokIosAppId,
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
  superwallApiKey: String.fromEnvironment('SUPERWALL_API_KEY'),
  paywallEnvironment:
      String.fromEnvironment('PAYWALL_ENV', defaultValue: 'dev'),
  tiktokAndroidAppId: String.fromEnvironment('TIKTOK_ANDROID_APP_ID'),
  tiktokIosAppId: String.fromEnvironment('TIKTOK_IOS_APP_ID'),
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
  superwallApiKey: String.fromEnvironment('SUPERWALL_API_KEY'),
  paywallEnvironment:
      String.fromEnvironment('PAYWALL_ENV', defaultValue: 'dev'),
  tiktokAndroidAppId: String.fromEnvironment('TIKTOK_ANDROID_APP_ID'),
  tiktokIosAppId: String.fromEnvironment('TIKTOK_IOS_APP_ID'),
);

EnvConfig get _currentEnv => kReleaseMode ? _prodEnv : _stagingEnv;

String get apiKey => _currentEnv.apiKey;
String get environment => _currentEnv.environment;
String get contentBaseUrl => _currentEnv.contentBaseUrl;
String get authBaseUrl => _currentEnv.authBaseUrl;
String get editStatsUrl => _currentEnv.editStatsUrl;
String get deleteAccountUrl => _currentEnv.deleteAccountBaseUrl;
String get donationBaseUrl => _currentEnv.donationBaseUrl;
String get donationToken => _currentEnv.donationToken;
String get superwallApiKey => _currentEnv.superwallApiKey;
String get paywallEnvironment => _currentEnv.paywallEnvironment;
String get tiktokAndroidAppId => _currentEnv.tiktokAndroidAppId;
String get tiktokIosAppId => _currentEnv.tiktokIosAppId;

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
