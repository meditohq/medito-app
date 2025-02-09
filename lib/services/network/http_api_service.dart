import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:medito/constants/constants.dart';
import 'package:medito/utils/retry_mixin.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HttpApiService with RetryMixin {
  static final HttpApiService _instance = HttpApiService._internal();
  final _client = http.Client();
  bool _isInitialized = false;
  Map<String, String> _headers = {};

  factory HttpApiService() {
    return _instance;
  }

  HttpApiService._internal() {
    _initializeWithoutAuth();
  }

  void _initializeWithoutAuth() {
    _headers = {
      'Content-Type': 'application/json',
    };
  }

  void initializeAuth() {
    if (!_isInitialized) {
      _updateAuthHeaders();
      _isInitialized = true;
    }
  }

  void _updateAuthHeaders() {
    var token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token != null) {
      _headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
    }
  }

  void updateHeaders(Map<String, String> headers) {
    _headers.addAll(headers);
  }

  Future<dynamic> getRequest(
    String uri, {
    Map<String, dynamic>? queryParameters,
  }) async {
    _updateAuthHeaders();
    var url = Uri.parse(contentBaseUrl + uri);
    if (queryParameters != null) {
      url = url.replace(
          queryParameters: queryParameters
              .map((key, value) => MapEntry(key, value.toString())));
    }

    final response = await _client.get(url, headers: _headers);
    _handleResponse(response);
    return jsonDecode(response.body);
  }

  Future<dynamic> postRequest(
    String uri, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    _updateAuthHeaders();
    var url = Uri.parse(contentBaseUrl + uri);
    if (queryParameters != null) {
      url = url.replace(
          queryParameters: queryParameters
              .map((key, value) => MapEntry(key, value.toString())));
    }

    final response = await _client.post(
      url,
      headers: _headers,
      body: data != null ? jsonEncode(data) : null,
    );
    _handleResponse(response);
    return jsonDecode(response.body);
  }

  Future<dynamic> deleteRequest(
    String uri, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    _updateAuthHeaders();
    var url = Uri.parse(contentBaseUrl + uri);
    if (queryParameters != null) {
      url = url.replace(
          queryParameters: queryParameters
              .map((key, value) => MapEntry(key, value.toString())));
    }

    final response = await _client.delete(
      url,
      headers: _headers,
      body: data != null ? jsonEncode(data) : null,
    );
    _handleResponse(response);
    return jsonDecode(response.body);
  }

  void _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    switch (response.statusCode) {
      case 400:
        throw BadRequestException(response.statusCode, response.body);
      case 401:
      case 403:
        throw UnauthorizedException(response.statusCode, response.body);
      case 422:
        throw InvalidInputException(response.statusCode, response.body);
      default:
        throw FetchDataException(
          response.statusCode,
          'Error occurred while communicating with server',
        );
    }
  }

  void dispose() {
    _client.close();
  }
}

sealed class CustomException implements Exception {
  final int? statusCode;
  final String? message;

  CustomException([this.statusCode, this.message]);

  @override
  String toString() {
    return '$message${statusCode != null ? ': $statusCode' : ''}';
  }
}

class FetchDataException extends CustomException {
  FetchDataException([super.statusCode, super.message]);
}

class BadRequestException extends CustomException {
  BadRequestException([super.statusCode, super.message]);
}

class UnauthorizedException extends CustomException {
  UnauthorizedException([super.statusCode, super.message]);
}

class InvalidInputException extends CustomException {
  InvalidInputException([super.statusCode, super.message]);
}
