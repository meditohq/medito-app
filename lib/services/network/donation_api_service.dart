import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/utils/logger.dart';

/// Interface for donation API service to enable clean separation of concerns
abstract class IDonationApiService {
  Future<Map<String, dynamic>> getRequest(
    String path, {
    Map<String, dynamic>? queryParams,
  });

  Future<Map<String, dynamic>> postRequest(
    String path, {
    dynamic body,
  });
}

/// Donation API service that uses its own base URL and authentication
/// Separate from the main HttpApiService to keep donation concerns isolated
class DonationApiService implements IDonationApiService {
  static DonationApiService? _instance;
  final _client = HttpClient();
  final _headers = <String, String>{};

  factory DonationApiService() {
    _instance ??= DonationApiService._internal();
    return _instance!;
  }

  DonationApiService._internal() {
    AppLogger.d('DONATION_API', 'Creating new DonationApiService instance');
    AppLogger.d('DONATION_API', 'Donation base URL: $donationBaseUrl');
    AppLogger.d('DONATION_API', 'Donation token: $donationToken');
    _client.connectionTimeout = const Duration(seconds: 30);
    _initializeHeaders();
  }

  void _initializeHeaders() {
    AppLogger.d('DONATION_API', 'Initializing donation API headers');
    _headers['Content-Type'] = 'application/json';
    _headers['Authorization'] = 'Bearer $donationToken';
  }

  @override
  Future<Map<String, dynamic>> getRequest(
    String path, {
    Map<String, dynamic>? queryParams,
  }) async =>
      _handleRequest(
        () async => _client.getUrl(_buildUri(path, queryParams)),
      );

  @override
  Future<Map<String, dynamic>> postRequest(
    String path, {
    dynamic body,
  }) async =>
      _handleRequest(
        () async => _client.postUrl(_buildUri(path)),
        body: body,
      );

  Uri _buildUri(String path, [Map<String, dynamic>? queryParams]) {
    AppLogger.d('DONATION_API', 'Base URL: "$donationBaseUrl"');
    AppLogger.d('DONATION_API', 'Path: "$path"');
    final fullUrl = '$donationBaseUrl$path';
    AppLogger.d('DONATION_API', 'Full URL: "$fullUrl"');
    return Uri.parse(fullUrl).replace(queryParameters: queryParams);
  }

  Future<Map<String, dynamic>> _handleRequest(
    Future<HttpClientRequest> Function() requestBuilder, {
    dynamic body,
  }) async {
    String? responseContent;
    try {
      AppLogger.d('DONATION_API', 'Starting HTTP request');
      final request = await requestBuilder();
      _headers.forEach(request.headers.set);

      AppLogger.d(
          'DONATION_API', 'Request headers set. Path: ${request.uri.path}');
      AppLogger.d('DONATION_API', 'Full request URL: ${request.uri}');
      AppLogger.d('DONATION_API', 'Request method: ${request.method}');

      if (body != null) {
        final encodedBody = jsonEncode(body);
        AppLogger.d('DONATION_API', 'Request body: $encodedBody');
        request.write(encodedBody);
        AppLogger.d('DONATION_API', 'Request body written to request');
      } else {
        AppLogger.d('DONATION_API', 'No request body');
      }

      AppLogger.d('DONATION_API', 'Sending request and waiting for response');
      final response =
          await request.close().timeout(const Duration(seconds: 30));
      AppLogger.d('DONATION_API', 'Response received, reading content');
      responseContent = await utf8.decodeStream(response);

      AppLogger.d('DONATION_API',
          'Response received. Status: ${response.statusCode}, Length: ${responseContent.length}');

      if (response.statusCode >= HttpStatus.badRequest) {
        AppLogger.e('DONATION_API', 'HTTP Error ${response.statusCode}');
        AppLogger.e('DONATION_API', 'Response content: $responseContent');
        AppLogger.e('DONATION_API', 'Request URL: ${request.uri}');
        AppLogger.e('DONATION_API', 'Request method: ${request.method}');
        throw _handleErrorResponse(response.statusCode);
      }

      return responseContent.isEmpty
          ? {}
          : _parseResponseContent(responseContent);
    } on FormatException catch (e, stackTrace) {
      AppLogger.e('DONATION_API', 'JSON parsing error', e, stackTrace);
      AppLogger.e('DONATION_API',
          'Content that failed to parse: ${responseContent ?? "null"}');
      throw const UnknownError();
    } on NetworkConnectionError catch (e, stackTrace) {
      AppLogger.e('DONATION_API', 'Network Error', e, stackTrace);
      throw NetworkConnectionError(originalException: e);
    } on TimeoutException catch (e, stackTrace) {
      AppLogger.e('DONATION_API', 'Request Timeout', e, stackTrace);
      throw const TimeoutError();
    } on HttpException catch (e, stackTrace) {
      AppLogger.e('DONATION_API', 'HTTP exception', e, stackTrace);
      throw Exception('HTTP exception');
    } catch (e, stackTrace) {
      AppLogger.e(
          'DONATION_API', 'Unexpected error in _handleRequest', e, stackTrace);
      AppLogger.e('DONATION_API', 'Error type: ${e.runtimeType}');
      AppLogger.e('DONATION_API', 'Error message: ${e.toString()}');
      if (e is SocketException) {
        AppLogger.e('DONATION_API', 'Socket error - check network connection');
      } else if (e is TlsException) {
        AppLogger.e(
            'DONATION_API', 'TLS/SSL error - check certificates or network');
      }
      throw const UnknownError();
    }
  }

  AppError _handleErrorResponse(int statusCode) {
    AppLogger.w('DONATION_API', 'HTTP Error $statusCode');

    return switch (statusCode) {
      HttpStatus.notFound => const NotFoundError(),
      HttpStatus.unauthorized => const UnauthorizedError(),
      >= 500 => const ServerError(),
      _ => const UnknownError(),
    };
  }

  Map<String, dynamic> _parseResponseContent(String content) {
    final decoded = jsonDecode(content);
    return decoded is Map<String, dynamic> ? decoded : {'results': decoded};
  }
}
