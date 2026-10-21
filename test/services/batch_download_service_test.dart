import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/services/downloads/batch_download_service.dart';
import 'package:medito/services/network/download_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  HttpServer? server;

  setUp(() async {
    HttpOverrides.global = null;
    tempDir = await Directory.systemTemp.createTemp('batch_download_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return tempDir.path;
      },
    );
  });

  tearDown(() async {
    await server?.close(force: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<String> serve(int sizeBytes) async {
    final bound = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server = bound;
    bound.listen((request) async {
      request.response.statusCode = HttpStatus.ok;
      request.response.contentLength = sizeBytes;
      request.response.add(List.filled(sizeBytes, 1));
      await request.response.close();
    });
    return 'http://${bound.address.host}:${bound.port}/test.mp3';
  }

  test('BatchDownloadItem serialization and deserialization', () {
    const item = BatchDownloadItem(
      url: 'https://example.com/audio.mp3',
      fileName: 'track1-file1.mp3',
      trackId: 'track1',
      fileId: 'file1',
    );

    final json = item.toJson();
    expect(json['url'], 'https://example.com/audio.mp3');
    expect(json['fileName'], 'track1-file1.mp3');
    expect(json['trackId'], 'track1');
    expect(json['fileId'], 'file1');

    final reconstructed = BatchDownloadItem.fromJson(json);
    expect(reconstructed.url, item.url);
    expect(reconstructed.fileName, item.fileName);
    expect(reconstructed.trackId, item.trackId);
    expect(reconstructed.fileId, item.fileId);
  });

  test('cleanupPartFiles deletes stale .part files', () async {
    final partFile1 = File('${tempDir.path}/track1-file1.mp3.part');
    final partFile2 = File('${tempDir.path}/track2-file2.mp3.part');
    final completedFile = File('${tempDir.path}/track3-file3.mp3');

    await partFile1.writeAsString('partial');
    await partFile2.writeAsString('partial');
    await completedFile.writeAsString('complete');

    final service = BatchDownloadService();
    await service.cleanupPartFiles();

    expect(await partFile1.exists(), isFalse);
    expect(await partFile2.exists(), isFalse);
    expect(await completedFile.exists(), isTrue);
  });

  test('downloadBatch downloads items concurrently and reports progress',
      () async {
    final url = await serve(1024);

    final items = [
      BatchDownloadItem(
        url: url,
        fileName: 't1-f1.mp3',
        trackId: 't1',
        fileId: 'f1',
      ),
      BatchDownloadItem(
        url: url,
        fileName: 't2-f2.mp3',
        trackId: 't2',
        fileId: 'f2',
      ),
    ];

    final progressUpdates = <BatchDownloadProgress>[];
    final service = BatchDownloadService(
      downloadService: DownloadService(),
    );

    await service.downloadBatch(
      items,
      onProgress: (p) => progressUpdates.add(p),
    );

    expect(await File('${tempDir.path}/t1-f1.mp3').exists(), isTrue);
    expect(await File('${tempDir.path}/t2-f2.mp3').exists(), isTrue);
    expect(await File('${tempDir.path}/t1-f1.mp3.part').exists(), isFalse);
    expect(await File('${tempDir.path}/t2-f2.mp3.part').exists(), isFalse);
    expect(progressUpdates.isNotEmpty, isTrue);
    expect(progressUpdates.last.completed, 2);
    expect(progressUpdates.last.total, 2);
  });
}
