import 'dart:developer' as dev;
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:medito/constants/constants.dart' hide AuthTokens;
import 'package:medito/constants/network_constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/models/auth/auth_tokens.dart';
import 'package:medito/services/secure_storage_service.dart';
import 'package:flutter/foundation.dart'; // Import for visibleForTesting

class HttpClientWrapper {
  HttpClient createClient() => HttpClient();
}

class AuthApiService {
  final SecureStorageService _secureStorage;
  final String _baseUrl;
  final String _apiKey;

  final HttpClient _client;
  final _headers = <String, String>{};
  AuthTokens? _tokens;

  // Use named constructors instead of factory+singleton pattern
  AuthApiService({
    SecureStorageService? secureStorage,
    HttpClientWrapper? httpClientWrapper,
    String? baseUrl,
    String? customApiKey,
  })  : _secureStorage = secureStorage ?? SecureStorageService(),
        _baseUrl = baseUrl ?? authBaseUrl,
        _apiKey =
            customApiKey ?? apiKey, // Use the global apiKey if none provided
        _client = (httpClientWrapper ?? HttpClientWrapper()).createClient() {
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
    dev.log('[AUTH] Attempting sign in', error: {
      'email': email != null ? 'provided' : 'not provided',
      'otp': otp != null ? 'provided' : 'not provided',
      'clientId': clientId,
      'url': '$_baseUrl${HTTPConstants.authSignIn}',
    });

    final response = await _post(
      HTTPConstants.authSignIn,
      body: {
        'client_id': clientId,
        if (email != null) 'email': email,
        if (otp != null) 'code': otp,
      },
    );

    dev.log('[AUTH] Sign in successful', error: {
      'clientId': response['client_id'],
      'hasEmail': response['email'] != null,
    });

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
    dev.log('[AUTH] Requesting OTP for email', error: {
      'email': email,
      'clientId': clientId,
      'url': '$_baseUrl${HTTPConstants.authOtpRequest}',
    });

    await _post(
      HTTPConstants.authOtpRequest,
      body: {
        'email': email,
        'client_id': clientId,
      },
    );

    dev.log('[AUTH] OTP request successful');
  }

  Future<AuthTokens> refreshToken(String refreshToken) async {
    dev.log('[AUTH_API] Starting token refresh', level: 1000);
    dev.log('[AUTH_API] Attempting to refresh token', error: {
      'token_length': refreshToken.length,
      'token_prefix': refreshToken.substring(0, min(10, refreshToken.length)),
      'timestamp': DateTime.now().toString(),
      'current_tokens_email': _tokens?.email,
      'current_tokens_clientId': _tokens?.clientId,
    });

    try {
      // Store a copy of the existing tokens for comparison
      final oldTokens = _tokens;

      // Send refresh token in the body instead of using it as a Bearer token
      final response = await _post(
        HTTPConstants.authTokensRefresh,
        body: {
          'refresh_token': refreshToken,
        },
      );

      dev.log('[AUTH_API] Raw refresh token response: ${jsonEncode(response)}',
          level: 1000);

      // Check explicitly if email is present in response
      final emailInResponse = response['email'] as String?;
      dev.log('[AUTH_API] Email in token refresh response: $emailInResponse',
          level: 1000);

      // Create new tokens object with the refreshed access token
      final tokens = AuthTokens(
        accessToken: response['access_token'] as String,
        refreshToken: refreshToken, // Keep the same refresh token
        expiresIn: response['expires_in'] as int,
        clientId: response['client_id'] as String? ??
            _tokens?.clientId ??
            '', // Get from response or preserve existing
        email: emailInResponse ??
            _tokens
                ?.email, // Try to get email from response or preserve existing
      );

      // Log differences between old and new tokens
      AuthTokens.logTokenDifferences(oldTokens, tokens);

      // Log what email value we're using
      dev.log(
          '[AUTH_API] Final email used in refreshed tokens: ${tokens.email}',
          level: 1000);
      dev.log(
          '[AUTH_API] Email source: ${emailInResponse != null ? 'from response' : 'preserved from old token'}',
          level: 1000);

      // Store the new tokens
      await setAuthTokens(tokens);

      dev.log('[AUTH_API] Token refresh successful', error: {
        'expires_in': tokens.expiresIn,
        'has_email': tokens.email != null,
        'email': tokens.email,
        'client_id': tokens.clientId,
        'token_prefix': tokens.accessToken.substring(0, 10),
        'refresh_token_length': tokens.refreshToken.length,
        'refresh_token_prefix': tokens.refreshToken
            .substring(0, min(10, tokens.refreshToken.length)),
      });

      return tokens;
    } catch (e) {
      dev.log('[AUTH_API] Token refresh failed', error: {
        'error': e.toString(),
        'token_length': refreshToken.length,
        'token_prefix': refreshToken.substring(0, min(10, refreshToken.length)),
      });

      // If we get an error response indicating invalid/expired refresh token,
      // clear the stored tokens to force a new login
      if (e is RefreshTokenError) {
        dev.log('[AUTH_API] Clearing tokens due to RefreshTokenError');
        await clearAuthTokens();
      }

      rethrow;
    }
  }

  Future<void> setAuthTokens(AuthTokens tokens) async {
    final previousEmail = _tokens?.email;
    _tokens = tokens;

    dev.log('[AUTH_API] setAuthTokens called', error: {
      'previous_email': previousEmail,
      'new_email': tokens.email,
      'email_changed': previousEmail != tokens.email,
    });

    if (tokens.refreshToken.isNotEmpty) {
      await _secureStorage.storeRefreshToken(tokens.refreshToken);
    }
    dev.log('[AUTH_API] Tokens updated', error: {
      'access_token_prefix':
          tokens.accessToken.substring(0, min(10, tokens.accessToken.length)),
      'has_refresh_token': tokens.refreshToken.isNotEmpty,
      'has_email': tokens.email != null,
      'email': tokens.email,
      'expires_in': tokens.expiresIn,
    });
  }

  Future<void> clearAuthTokens() async {
    _tokens = null;
    await _secureStorage.clearRefreshToken();
  }

  Future<String?> getStoredRefreshToken() async {
    dev.log('[AUTH] Getting stored refresh token');
    final token = await _secureStorage.getRefreshToken();
    if (token != null) {
      dev.log('[AUTH] Found stored refresh token', error: {
        'token_length': token.length,
        'token_prefix': token.substring(0, min(10, token.length)),
      });
    } else {
      dev.log('[AUTH] No stored refresh token found');
    }
    return token;
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    dynamic body,
  }) async {
    try {
      // Ensure the path is properly combined with base URL
      final uri = Uri.parse('$_baseUrl$path');

      // Log the API key being used
      dev.log('[AUTH] API Key check',
          error: jsonEncode({
            'api_key': _apiKey,
            'is_empty': _apiKey.isEmpty,
            'length': _apiKey.length,
          }));

      final request = await _client.postUrl(uri);

      // Add headers
      _headers.forEach(request.headers.set);

      // Log complete headers map
      var headersMap = {};
      request.headers.forEach((name, values) {
        headersMap[name] = values;
      });

      dev.log('[AUTH] Complete request details',
          error: jsonEncode({
            'url': uri.toString(),
            'method': 'POST',
            'all_headers': headersMap,
            'body': body,
            'auth_type': 'API Key',
          }));

      if (body != null) {
        final encodedBody = jsonEncode(body);
        request.write(encodedBody);
        dev.log('[AUTH] Request body',
            error: jsonEncode({
              'raw': body,
              'encoded': encodedBody,
            }));
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
      final hasEmail = parsedContent != null &&
          parsedContent is Map<String, dynamic> &&
          parsedContent.containsKey('email');

      dev.log('[AUTH_API] Response contains email: $hasEmail', level: 1000);
      if (hasEmail) {
        dev.log('[AUTH_API] Email in response: ${parsedContent['email']}',
            level: 1000);
      }

      dev.log('[AUTH_API] Complete response details',
          error: jsonEncode({
            'status_code': response.statusCode,
            'all_headers': responseHeadersMap,
            'raw_content': content,
            'parsed_content': parsedContent,
          }));

      if (response.statusCode >= HttpStatus.badRequest) {
        dev.log('[AUTH] Request failed', error: {
          'status_code': response.statusCode,
          'raw_content': content,
          'parsed_content': content.isNotEmpty ? jsonDecode(content) : null,
        });
        handleErrorResponse(response.statusCode, content);
        throw Exception('handleErrorResponse did not throw');
      }

      return content.isEmpty ? {} : jsonDecode(content) as Map<String, dynamic>;
    } on SocketException catch (e) {
      dev.log('[AUTH] Network error', error: {
        'error': e.toString(),
        'address': e.address?.toString(),
        'port': e.port,
      });
      throw const NoInternetError();
    } on TimeoutException catch (e) {
      dev.log('[AUTH] Request timeout', error: {
        'error': e.toString(),
        'duration': e.duration?.toString(),
      });
      throw const TimeoutError();
    } catch (e) {
      dev.log('[AUTH] Unexpected error in _post', error: {
        'error': e.toString(),
        'type': e.runtimeType.toString(),
      });
      rethrow;
    }
  }

  @visibleForTesting
  void handleErrorResponse(int statusCode, [String? content]) {
    dev.log('HTTP Error $statusCode', level: 900);

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
        final String? emailFromError = errorData['email']
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
            message: errorMessage ??
                'This device is already associated with an email account.',
          );
        }

        if (errorMessage != null) {
          if (errorMessage.contains('Invalid refresh token') ||
              errorMessage.contains('Expired refresh token') ||
              errorMessage.contains('Token has been revoked')) {
            throw const RefreshTokenError();
          }
        }
      } catch (e) {
        if (e is RateLimitError ||
            e is EmailExistsError ||
            e is RefreshTokenError) {
          rethrow; // Rethrow specific exceptions
        }
        dev.log('[AUTH] Error parsing error response', error: e);
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
