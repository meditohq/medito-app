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

class EmailExistsException implements Exception {
  final String message;
  const EmailExistsException(this.message);

  @override
  String toString() => message;
}

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
    dev.log('[AUTH] Attempting to refresh token', error: {
      'token_length': refreshToken.length,
      'token_prefix': refreshToken.substring(0, min(10, refreshToken.length)),
      'timestamp': DateTime.now().toString(),
    });

    try {
      // Send refresh token in the body instead of using it as a Bearer token
      final response = await _post(
        HTTPConstants.authTokensRefresh,
        body: {
          'refresh_token': refreshToken,
        },
      );

      // Create new tokens object with the refreshed access token
      final tokens = AuthTokens(
        accessToken: response['access_token'] as String,
        refreshToken: refreshToken, // Keep the same refresh token
        expiresIn: response['expires_in'] as int,
        clientId: _tokens?.clientId ?? '', // Preserve client ID if available
        email: _tokens?.email, // Preserve email if available
      );

      // Store the new tokens
      await setAuthTokens(tokens);

      dev.log('[AUTH] Token refresh successful', error: {
        'expires_in': tokens.expiresIn,
        'has_email': tokens.email != null,
        'token_prefix': tokens.accessToken.substring(0, 10),
        'refresh_token_length': tokens.refreshToken.length,
        'refresh_token_prefix': tokens.refreshToken
            .substring(0, min(10, tokens.refreshToken.length)),
      });

      return tokens;
    } catch (e) {
      dev.log('[AUTH] Token refresh failed', error: {
        'error': e.toString(),
        'token_length': refreshToken.length,
        'token_prefix': refreshToken.substring(0, min(10, refreshToken.length)),
      });

      // If we get an error response indicating invalid/expired refresh token,
      // clear the stored tokens to force a new login
      if (e is RefreshTokenError) {
        dev.log('[AUTH] Clearing tokens due to RefreshTokenError');
        await clearAuthTokens();
      }

      rethrow;
    }
  }

  Future<void> setAuthTokens(AuthTokens tokens) async {
    _tokens = tokens;
    if (tokens.refreshToken.isNotEmpty) {
      await _secureStorage.storeRefreshToken(tokens.refreshToken);
    }
    dev.log('[AUTH] Tokens updated', error: {
      'access_token_prefix': tokens.accessToken.substring(0, 10),
      'has_refresh_token': tokens.refreshToken.isNotEmpty,
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

      dev.log('[AUTH] Complete response details',
          error: jsonEncode({
            'status_code': response.statusCode,
            'all_headers': responseHeadersMap,
            'raw_content': content,
            'parsed_content': content.isNotEmpty ? jsonDecode(content) : null,
          }));

      if (response.statusCode >= HttpStatus.badRequest) {
        dev.log('[AUTH] Request failed', error: {
          'status_code': response.statusCode,
          'raw_content': content,
          'parsed_content': content.isNotEmpty ? jsonDecode(content) : null,
        });
        throw _handleErrorResponse(response.statusCode, content);
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
    } on EmailExistsException {
      rethrow;
    } catch (e) {
      dev.log('[AUTH] Unexpected error', error: {
        'error': e.toString(),
        'type': e.runtimeType.toString(),
      });
      rethrow;
    }
  }

  AppError _handleErrorResponse(int statusCode, [String? content]) {
    dev.log('HTTP Error $statusCode', level: 900);

    // If content is available, parse it to see if we have specific error information
    if (content != null && content.isNotEmpty) {
      try {
        final Map<String, dynamic> errorData =
            jsonDecode(content) as Map<String, dynamic>;
        final String? errorMessage = errorData['error'] as String?;
        final String? errorCode = errorData['code'] as String?;

        if (errorCode == 'EMAIL_ASSOCIATED' &&
            statusCode == HttpStatus.forbidden) {
          throw EmailExistsException(
              errorMessage ?? 'Email exists for this account');
        }

        if (errorMessage != null) {
          if (errorMessage.contains('Invalid refresh token') ||
              errorMessage.contains('Expired refresh token') ||
              errorMessage.contains('Token has been revoked')) {
            return const RefreshTokenError();
          }
        }
      } catch (e) {
        // If the error is our custom exception, rethrow it
        if (e is EmailExistsException) {
          throw e;
        }
        // Otherwise log parsing error and continue with default handling
        dev.log('[AUTH] Error parsing error response', error: e);
      }
    }

    return switch (statusCode) {
      HttpStatus.notFound => const NotFoundError(),
      HttpStatus.unauthorized => const UnauthorizedError(),
      >= 500 => const ServerError(),
      _ => const UnknownError(),
    };
  }
}
