import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/track/track.dart';
import 'package:medito/repositories/downloader/downloader_repository.dart';
import 'package:medito/services/watch_download_service.dart';

class _Files implements DownloaderRepository {
  String? path;
  String? requested;
  @override
  Future<String?> getDownloadedFile(String name) async {
    requested = name;
    return path;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late _Files files;
  late Directory temporary;
  final calls = <MethodCall>[];
  const channel = WatchDownloadService.channel;
  final track = Track(
    id: 'track',
    title: 'Session',
    description: '',
    coverUrl: '',
    isPublished: true,
    hasBackgroundSound: false,
    voices: [
      TrackVoice(
        guideName: 'Selected guide',
        audioFiles: [
          TrackAudioFile(
            id: 'selected-file',
            path: 'https://example.test/audio.mp3',
            duration: 300000,
          ),
        ],
      ),
    ],
  );

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('medito-watch-test');
    files = _Files();
    container = ProviderContainer(
      overrides: [downloaderRepositoryProvider.overrideWithValue(files)],
    );
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'downloadsGet') {
            return {
              'available': true,
              'items': [
                {'fileId': 'selected-file', 'state': 'queued'},
              ],
            };
          }
          return null;
        });
  });
  tearDown(() async {
    container.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await temporary.delete(recursive: true);
  });

  test(
    'sends the downloaded file with its exact variant and byte count',
    () async {
      final file = File('${temporary.path}/session.mp3');
      await file.writeAsBytes([1, 2, 3, 4]);
      files.path = file.path;
      await container.read(watchDownloadServiceProvider).send(track);
      final payload = calls.single.arguments as Map;
      expect(files.requested, 'track-selected-file.mp3');
      expect(payload['path'], file.path);
      expect(payload['fileId'], 'selected-file');
      expect(payload['guide'], 'Selected guide');
      expect(payload['durationMs'], 300000);
      expect(payload['bytes'], 4);
      expect(file.existsSync(), isTrue);
    },
  );

  test('a missing phone file never queues a transfer', () async {
    await expectLater(
      container.read(watchDownloadServiceProvider).send(track),
      throwsA(isA<PlatformException>()),
    );
    expect(calls, isEmpty);
  });

  test('removing a watch copy only calls the watch bridge', () async {
    await container.read(watchDownloadServiceProvider).remove({
      'fileId': 'selected-file',
      'requestId': 'request',
    });
    expect(calls.single.method, 'downloadsRemove');
    expect(calls.single.arguments, {
      'fileId': 'selected-file',
      'requestId': 'request',
    });
    expect(files.requested, isNull);
  });

  test(
    'a queued snapshot stays queued until native watch acknowledgement',
    () async {
      final snapshot = await container
          .read(watchDownloadServiceProvider)
          .refresh();
      expect(snapshot.available, isTrue);
      expect(snapshot.items.single['state'], 'queued');
    },
  );
}
