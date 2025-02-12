import 'dart:io';

const Duration kTimeoutDuration = Duration(seconds: 30);
const int kMaxRetries = 3;
const String kContentTypeHeader = HttpHeaders.contentTypeHeader;
const String kAuthorizationHeader = HttpHeaders.authorizationHeader;
