import 'dart:io';
import 'package:medito/exceptions/app_error.dart';

class DownloadService {
  static final DownloadService _instance = DownloadService._internal();
  final _client = HttpClient();

  factory DownloadService() {
    return _instance;
  }

  DownloadService._internal();

  Future<void> downloadFile(
    String url,
    String savePath, {
    void Function(int received, int total)? onProgress,
  }) async {
    final request = await _client.getUrl(Uri.parse(url));
    request.headers.add(HttpHeaders.acceptEncodingHeader, '*');

    final response = await request.close();
    final contentLength = response.contentLength;
    var receivedBytes = 0;

    final file = File(savePath);
    final sink = file.openWrite();

    try {
      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        onProgress?.call(receivedBytes, contentLength);
      }
    } finally {
      await sink.close();
    }

    if (response.statusCode >= 400) {
      await file.delete();
      throw switch (response.statusCode) {
        HttpStatus.notFound => const NotFoundError(),
        HttpStatus.unauthorized => const UnauthorizedError(),
        >= 500 => const ServerError(),
        _ => const UnknownError(),
      };
    }
  }

  void dispose() {
    _client.close();
  }
}
