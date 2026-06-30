import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart'; // Import for visibleForTesting
import 'package:medito/constants/constants.dart' hide AuthTokens;
import 'package:medito/constants/network_constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/models/auth/auth_tokens.dart';
import 'package:medito/services/secure_storage_service.dart';
import 'package:medito/utils/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/services/analytics/crashlytics_service.dart';

class HttpClientWrapper {
  HttpClient createClient() => HttpClient();
}

class AuthApiService {
  final SecureStorageService _secureStorage;
  final String _baseUrl;
  final String _apiKey;
  final CrashlyticsService _crashlyticsService;

  final HttpClient _client;
  final _headers = <String, String>{};
  AuthTokens? _tokens;

  // Use named constructors instead of factory+singleton pattern
  AuthApiService({
    SecureStorageService? secureStorage,
    HttpClientWrapper? httpClientWrapper,
    String? baseUrl,
    String? customApiKey,
    CrashlyticsService? crashlyticsService,
  }) : _secureStorage = secureStorage ?? SecureStorageService(),
       _baseUrl = baseUrl ?? authBaseUrl,
       _apiKey =
           customApiKey ?? apiKey, // Use the global apiKey if none provided
       _client = (httpClientWrapper ?? HttpClientWrapper()).createClient(),
       _crashlyticsService = crashlyticsService ?? CrashlyticsService() {
    _client.connectionTimeout = kTimeoutDuration;
    _initializeHeaders();
  }

  void _initializeHeaders() {
    _headers[kContentTypeHeader] = ContentType.json.value;
    _headers[kAuthorizationHeader] = 'Bearer $_apiKey';
  }

  Future<AuthTokens> signIn({
    String? email,
    String? otp,
    required String clientId,
  }) async {
    AppLogger.i(
      'AUTH',
      'Attempting sign in. Email: ${email != null}, OTP: ${otp != null}, ClientId: $clientId',
    );

    final response = await _post(
      HTTPConstants.authSignIn,
      body: {'client_id': clientId, 'email': ?email, 'code': ?otp},
    );

    AppLogger.i(
      'AUTH',
      'Sign in successful. ClientId: ${response['client_id']}, HasEmail: ${response['email'] != null}',
    );

    final tokens = AuthTokens(
      accessToken: response['access_token'] as String,
      refreshToken: response['refresh_token'] as String,
      expiresIn: response['expires_in'] as int,
      clientId: response['client_id'] as String,
      email: response['email'] as String?,
    );

    await setAuthTokens(tokens);
    return tokens;
  }

  Future<void> requestOtp(String email, String clientId) async {
    AppLogger.i(
      'AUTH',
      'Requesting OTP for email: $email, ClientId: $clientId',
    );

    await _post(
      HTTPConstants.authOtpRequest,
      body: {'email': email, 'client_id': clientId},
    );

    AppLogger.i('AUTH', 'OTP request successful for email: $email');
  }

  Future<AuthTokens> refreshToken(String refreshToken) async {
    AppLogger.i('AUTH_API', 'Starting token refresh');
    AppLogger.d(
      'AUTH_API',
      'Attempting token refresh. TokenLength: ${refreshToken.length}, Prefix: ${refreshToken.substring(0, min(10, refreshToken.length))}',
    );

    try {
      // Store a copy of the existing tokens for comparison
      final oldTokens = _tokens;

      // Send refresh token in the body instead of using it as a Bearer token
      final response = await _post(
        HTTPConstants.authTokensRefresh,
        body: {'refresh_token': refreshToken},
      );

      AppLogger.d(
        'AUTH_API',
        'Raw refresh token response: ${jsonEncode(response)}',
      );

      // Check explicitly if email is present in response
      final emailInResponse = response['email'] as String?;
      AppLogger.d(
        'AUTH_API',
        'Email in token refresh response: $emailInResponse',
      );

      // Create new tokens object with the refreshed access token
      final tokens = AuthTokens(
        accessToken: response['access_token'] as String,
        refreshToken:
            response['refresh_token']
                as String, // Use refresh token from response
        expiresIn: response['expires_in'] as int,
        clientId:
            response['client_id'] as String? ??
            _tokens?.clientId ??
            '', // Get from response or preserve existing
        email:
            emailInResponse ??
            _tokens
                ?.email, // Try to get email from response or preserve existing
      );

      // Log differences between old and new tokens
      AuthTokens.logTokenDifferences(oldTokens, tokens);

      // Log what email value we're using
      AppLogger.d(
        'AUTH_API',
        'Final email used in refreshed tokens: ${tokens.email}',
      );
      AppLogger.d(
        'AUTH_API',
        'Email source: ${emailInResponse != null ? 'from response' : 'preserved from old token'}',
      );

      // Store the new tokens
      await setAuthTokens(tokens);

      AppLogger.i(
        'AUTH_API',
        'Token refresh successful. ExpiresIn: ${tokens.expiresIn}, Email: ${tokens.email}, ClientId: ${tokens.clientId}',
      );

      return tokens;
    } catch (e, stackTrace) {
      AppLogger.e('AUTH_API', 'Token refresh failed', e, stackTrace);

      // If we get an error response indicating invalid/expired refresh token,
      // clear the stored tokens to force a new login
      if (e is RefreshTokenError) {
        AppLogger.w('AUTH_API', 'Clearing tokens due to RefreshTokenError');
        await clearAuthTokens();
      }

      rethrow;
    }
  }

  Future<void> setAuthTokens(AuthTokens tokens) async {
    final previousEmail = _tokens?.email;
    _tokens = tokens;

    AppLogger.d(
      'AUTH_API',
      'setAuthTokens called. PreviousEmail: $previousEmail, NewEmail: ${tokens.email}',
    );

    if (tokens.refreshToken.isNotEmpty) {
      try {
        // Directly use the secure storage service's storeRefreshToken method
        // which already has its own comprehensive retry mechanism
        await _secureStorage.storeRefreshToken(tokens.refreshToken);
        AppLogger.d('AUTH_API', 'Refresh token saved to secure storage');
      } catch (e, stack) {
        // This error is critical - log it extensively
        AppLogger.e(
          'AUTH_API',
          'CRITICAL: Failed to save refresh token to secure storage. User may experience unexpected logout on next app start.',
          e,
          stack,
        );

        // Track this critical error in Firebase Analytics
        try {
          final packageInfo = await PackageInfo.fromPlatform();
          await FirebaseAnalyticsService().logEvent(
            name: FirebaseAnalyticsService.eventAuthTokenStorageFailed,
            parameters: {
              'error': e.toString(),
              'stack_trace': stack.toString(),
              'version': packageInfo.version,
              'build_number': packageInfo.buildNumber,
            },
          );
          // Also log this critical failure to Crashlytics
          _crashlyticsService.recordError(
            e,
            stack,
            reason: 'CRITICAL: Failed to save refresh token to secure storage',
          );
        } catch (analyticsError) {
          AppLogger.e(
            'AUTH_API',
            'Failed to log token storage failure to analytics',
            analyticsError,
          );
        }
      }
    }

    AppLogger.d(
      'AUTH_API',
      'Tokens updated. HasRefreshToken: ${tokens.refreshToken.isNotEmpty}, Email: ${tokens.email}, ExpiresIn: ${tokens.expiresIn}',
    );
  }

  Future<void> clearAuthTokens() async {
    _tokens = null;
    await _secureStorage.clearRefreshToken();
  }

  Future<String?> getStoredRefreshToken() async {
    AppLogger.d('AUTH', 'Getting stored refresh token');
    final token = await _secureStorage.getRefreshToken();
    if (token != null) {
      AppLogger.d(
        'AUTH',
        'Found stored refresh token. Length: ${token.length}, Prefix: ${token.substring(0, min(10, token.length))}',
      );
    } else {
      AppLogger.d('AUTH', 'No stored refresh token found');
    }
    return token;
  }

  Future<Map<String, dynamic>> _post(String path, {dynamic body}) async {
    try {
      // Ensure the path is properly combined with base URL
      final uri = Uri.parse('$_baseUrl$path');

      AppLogger.d('AUTH', 'API Key Length: ${_apiKey.length}');

      final request = await _client.postUrl(uri);

      // Add headers
      _headers.forEach(request.headers.set);

      // Log complete headers map
      var headersMap = {};
      request.headers.forEach((name, values) {
        headersMap[name] = values;
      });

      AppLogger.d(
        'AUTH',
        'POST Request: ${uri.toString()}, Body: ${body != null}',
      );

      if (body != null) {
        final encodedBody = jsonEncode(body);
        request.write(encodedBody);
        AppLogger.d('AUTH', 'Request Body: $encodedBody');
      }

      final response = await request.close().timeout(kTimeoutDuration);
      final content = await utf8.decodeStream(response);

      // Log response with all headers
      var responseHeadersMap = {};
      response.headers.forEach((name, values) {
        responseHeadersMap[name] = values;
      });

      // Add specific logging for email in auth responses
      final parsedContent = content.isNotEmpty ? jsonDecode(content) : null;
      final hasEmail =
          parsedContent != null &&
          parsedContent is Map<String, dynamic> &&
          parsedContent.containsKey('email');

      AppLogger.d('AUTH_API', 'Response contains email: $hasEmail');
      if (hasEmail) {
        AppLogger.d('AUTH_API', 'Email in response: ${parsedContent['email']}');
      }

      AppLogger.d(
        'AUTH_API',
        'Response Status: ${response.statusCode}, Content Length: ${content.length}',
      );

      if (response.statusCode >= HttpStatus.badRequest) {
        AppLogger.w(
          'AUTH',
          'Request failed. Status: ${response.statusCode}, Content: $content',
        );
        handleErrorResponse(response.statusCode, content);
        throw Exception('handleErrorResponse did not throw');
      }

      return content.isEmpty ? {} : jsonDecode(content) as Map<String, dynamic>;
    } on SocketException catch (e, stackTrace) {
      AppLogger.e('AUTH', 'Network error (SocketException)', e, stackTrace);
      throw const NetworkConnectionError();
    } on TimeoutException catch (e, stackTrace) {
      AppLogger.e('AUTH', 'Request timeout', e, stackTrace);
      throw const TimeoutError();
    } catch (e, stackTrace) {
      AppLogger.e('AUTH', 'Unexpected error in _post', e, stackTrace);
      rethrow;
    }
  }

  @visibleForTesting
  void handleErrorResponse(int statusCode, [String? content]) {
    AppLogger.w('AUTH', 'HTTP Error $statusCode');

    if (statusCode == HttpStatus.unprocessableEntity ||
        statusCode == HttpStatus.notAcceptable) {
      throw const InactiveEmailError();
    }

    if (content != null && content.isNotEmpty) {
      try {
        final Map<String, dynamic> errorData =
            jsonDecode(content) as Map<String, dynamic>;
        final String? errorMessage =
            errorData['message'] as String? ?? errorData['error'] as String?;
        final String? errorCode = errorData['code'] as String?;
        final bool? rateLimited =
            errorData['rate_limited'] as bool?; // Check for rate limit flag
        final int? retryAfter =
            errorData['retry_after'] as int?; // Check for retry after seconds
        final String? emailFromError =
            errorData['email']
                as String?; // Attempt to get email from error response

        // Handle Rate Limit specifically
        if (statusCode == HttpStatus.tooManyRequests &&
            rateLimited == true &&
            retryAfter != null) {
          throw RateLimitError(
            tryAfterSeconds: retryAfter,
            message: errorMessage ?? 'Too many requests. Please wait.',
          );
        }

        // Handle Email Exists specifically using the new AppError type
        if (errorCode == 'EMAIL_ASSOCIATED' &&
            statusCode == HttpStatus.forbidden) {
          throw EmailExistsError(
            email: emailFromError, // Pass the email if available
            message:
                errorMessage ??
                'This device is already associated with an email account.',
          );
        }

        // Handle Email Mismatch - client ID exists but is associated with different email
        if (errorCode == 'EMAIL_MISMATCH' &&
            statusCode == HttpStatus.forbidden) {
          throw EmailMismatchError(
            message:
                errorMessage ??
                'This account is already linked to a different email address. Please use the original email.',
          );
        }

        if (errorMessage != null) {
          if (errorMessage.contains('Invalid refresh token') ||
              errorMessage.contains('Expired refresh token') ||
              errorMessage.contains('Token has been revoked')) {
            _crashlyticsService.recordError(
              const RefreshTokenError(),
              StackTrace.current,
              reason: 'AuthAPI: Refresh token invalid, expired, or revoked',
            );
            throw const RefreshTokenError();
          }
        }
      } catch (e) {
        if (e is RateLimitError ||
            e is EmailExistsError ||
            e is EmailMismatchError ||
            e is RefreshTokenError ||
            e is InactiveEmailError) {
          rethrow; // Rethrow specific exceptions
        }
        AppLogger.e(
          'AUTH',
          'Error parsing error response content: $content',
          e,
        );
        // Fall through to default handling if parsing failed
      }
    }

    // Default handling - Always throw an AppError
    switch (statusCode) {
      case HttpStatus.notFound:
        throw const NotFoundError();
      case HttpStatus.unauthorized:
        throw const UnauthorizedError();
      default:
        if (statusCode >= 500) {
          throw const ServerError();
        } else {
          throw const UnknownError();
        }
    }
  }
}
