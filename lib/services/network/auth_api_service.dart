import 'dart:developer' as dev;
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/network_constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/services/secure_storage_service.dart';

class AuthApiService {
  static AuthApiService? _instance;
  final _client = HttpClient();
  final _headers = <String, String>{};
  final _secureStorage = SecureStorageService();
  AuthTokens? _tokens;

  factory AuthApiService() {
    _instance ??= AuthApiService._internal();
    return _instance!;
  }

  AuthApiService._internal() {
    _client.connectionTimeout = kTimeoutDuration;
    _initializeHeaders();
  }

  void _initializeHeaders() {
    _headers[kContentTypeHeader] = ContentType.json.value;
    _headers[kAuthorizationHeader] = 'Bearer $apiKey';
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
      'url': '$authBaseUrl${HTTPConstants.authSignIn}',
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
      'url': '$authBaseUrl${HTTPConstants.authOtpRequest}',
    });

    await _post(
      HTTPConstants.authOtpRequest,
      body: {
        'email': email,
      },
    );

    dev.log('[AUTH] OTP request successful');
  }

  Future<AuthTokens> refreshToken(String refreshToken) async {
    dev.log('[AUTH] Attempting to refresh token');

    try {
      // Send refresh token in the body instead of using it as a Bearer token
      final response = await _post(
        HTTPConstants.authTokensRefresh,
        body: {
          'refresh_token': refreshToken,
        },
      );

      if (_tokens == null) {
        dev.log('[AUTH] No existing tokens found during refresh');
        throw const RefreshTokenError();
      }

      final tokens = AuthTokens(
        accessToken: response['access_token'] as String,
        refreshToken: refreshToken,
        expiresIn: response['expires_in'] as int,
        clientId: _tokens!.clientId,
        email: _tokens!.email,
      );

      await setAuthTokens(tokens);
      return tokens;
    } catch (e) {
      dev.log('Token refresh failed', error: e);
      rethrow;
    }
  }

  Future<void> setAuthTokens(AuthTokens tokens) async {
    _tokens = tokens;
    if (tokens.refreshToken.isNotEmpty) {
      await _secureStorage.storeRefreshToken(tokens.refreshToken);
    }
  }

  Future<void> clearAuthTokens() async {
    _tokens = null;
    await _secureStorage.clearRefreshToken();
  }

  Future<String?> getStoredRefreshToken() async {
    return _secureStorage.getRefreshToken();
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    dynamic body,
  }) async {
    try {
      final uri = Uri.parse('$authBaseUrl$path');

      // Log the API key being used
      dev.log('[AUTH] API Key check',
          error: jsonEncode({
            'api_key': apiKey,
            'is_empty': apiKey.isEmpty,
            'length': apiKey.length,
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

    try {
      // If content is available, parse it to see if we have specific error information
      if (content != null && content.isNotEmpty) {
        final Map<String, dynamic> errorData =
            jsonDecode(content) as Map<String, dynamic>;
        final String? errorMessage = errorData['error'] as String?;

        if (errorMessage != null) {
          if (errorMessage.contains('Invalid refresh token') ||
              errorMessage.contains('Expired refresh token') ||
              errorMessage.contains('Token has been revoked')) {
            return const RefreshTokenError();
          }
        }
      }
    } catch (e) {
      // If parsing fails, fall back to the default error handling
      dev.log('[AUTH] Error parsing error response', error: e);
    }

    return switch (statusCode) {
      HttpStatus.notFound => const NotFoundError(),
      HttpStatus.unauthorized => const UnauthorizedError(),
      >= 500 => const ServerError(),
      _ => const UnknownError(),
    };
  }
}
