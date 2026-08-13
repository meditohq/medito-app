import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/services/network/download_service.dart';

/// Regression tests for the download path used by background sounds and track
/// downloads. Callers decide whether something is downloaded by checking that
/// the destination file exists, so a failed download MUST NOT leave a file
/// behind — a truncated fragment used to be cached as a complete download
/// forever, and the audio player then failed on it every single time.
void main() {
  late Directory tempDir;
  late String savePath;
  HttpServer? server;
  ServerSocket? rawServer;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('download_service_test');
    savePath = '${tempDir.path}/sound.mp3';
  });

  tearDown(() async {
    await server?.close(force: true);
    await rawServer?.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<String> serve(Future<void> Function(HttpRequest) handler) async {
    final bound = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server = bound;
    bound.listen(handler);

    return 'http://${bound.address.host}:${bound.port}/sound.mp3';
  }

  Future<bool> partExists() => File('$savePath.part').exists();

  test('a complete download lands at savePath and leaves no .part', () async {
    final url = await serve((request) async {
      request.response.add(List.filled(2048, 7));
      await request.response.close();
    });

    await DownloadService().downloadFile(url, savePath);

    expect(await File(savePath).exists(), isTrue);
    expect(await File(savePath).length(), 2048);
    expect(await partExists(), isFalse);
  });

  test('an error status throws and writes no file', () async {
    final url = await serve((request) async {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('not found');
      await request.response.close();
    });

    await expectLater(
      DownloadService().downloadFile(url, savePath),
      throwsA(isA<NotFoundError>()),
    );

    expect(await File(savePath).exists(), isFalse);
    expect(await partExists(), isFalse);
  });

  test('a connection dropped mid-body leaves no partial file', () async {
    // Raw socket rather than HttpServer: we need to promise more bytes than we
    // send and then kill the connection, which dart:io's HttpResponse won't do.
    final bound = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    rawServer = bound;
    bound.listen((socket) {
      socket.listen((_) {
        socket.write(
          'HTTP/1.1 200 OK\r\n'
          'Content-Length: 4096\r\n'
          'Content-Type: audio/mpeg\r\n\r\n',
        );
        socket.add(List.filled(512, 7));
        socket.flush().then((_) => socket.destroy());
      });
    });
    final url = 'http://${bound.address.host}:${bound.port}/sound.mp3';

    await expectLater(
      DownloadService().downloadFile(url, savePath),
      throwsA(anything),
    );

    expect(
      await File(savePath).exists(),
      isFalse,
      reason: 'a truncated download must not be cached as complete',
    );
    expect(await partExists(), isFalse);
  });
}
