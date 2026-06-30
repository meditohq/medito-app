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

  Future<Map<String, dynamic>> postRequest(String path, {dynamic body});
}

/// Donation API service that uses its own base URL and authentication
/// Separate from the main HttpApiService to keep donation concerns isolated
class DonationApiService implements IDonationApiService {
  static DonationApiService? _instance;
  final _headers = <String, String>{};

  factory DonationApiService() {
    _instance ??= DonationApiService._internal();
    return _instance!;
  }

  DonationApiService._internal() {
    _initializeHeaders();
  }

  void _initializeHeaders() {
    _headers['Content-Type'] = 'application/json';
    _headers['Authorization'] = 'Bearer $donationToken';
  }

  @override
  Future<Map<String, dynamic>> getRequest(
    String path, {
    Map<String, dynamic>? queryParams,
  }) async => _handleRequest(() async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 30);
    final request = await client.getUrl(_buildUri(path, queryParams));
    return (request, client);
  });

  @override
  Future<Map<String, dynamic>> postRequest(String path, {dynamic body}) async =>
      _handleRequest(() async {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 30);
        final request = await client.postUrl(_buildUri(path));
        return (request, client);
      }, body: body);

  Uri _buildUri(String path, [Map<String, dynamic>? queryParams]) {
    if (donationBaseUrl.isEmpty) {
      throw ArgumentError('DONATION_BASE_URL is not configured');
    }
    final fullUrl = '$donationBaseUrl$path';

    return Uri.parse(fullUrl).replace(queryParameters: queryParams);
  }

  Future<Map<String, dynamic>> _handleRequest(
    Future<(HttpClientRequest, HttpClient)> Function() requestBuilder, {
    dynamic body,
  }) async {
    String? responseContent;
    HttpClient? client;

    try {
      final (request, requestClient) = await requestBuilder();
      client = requestClient;
      _headers.forEach(request.headers.set);

      if (body != null) {
        final encodedBody = jsonEncode(body);
        AppLogger.d('DONATION_API', 'REQUEST: $encodedBody');
        request.write(encodedBody);
      }

      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      responseContent = await utf8.decodeStream(response);

      AppLogger.d('DONATION_API', 'RESPONSE: $responseContent');

      if (response.statusCode >= HttpStatus.badRequest) {
        throw _handleErrorResponse(response.statusCode);
      }

      return responseContent.isEmpty
          ? {}
          : _parseResponseContent(responseContent);
    } on FormatException catch (e, stackTrace) {
      AppLogger.e('DONATION_API', 'JSON parsing error', e, stackTrace);
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
        'DONATION_API',
        'Unexpected error in _handleRequest',
        e,
        stackTrace,
      );
      throw const UnknownError();
    } finally {
      client?.close();
    }
  }

  AppError _handleErrorResponse(int statusCode) {
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
