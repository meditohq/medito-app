import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/track/track.dart';
import 'package:medito/repositories/downloader/downloader_repository.dart';
import 'package:medito/utils/utils.dart';

final watchDownloadsProvider = StreamProvider.autoDispose<WatchDownloads>((
  ref,
) async* {
  if (!Platform.isIOS && !Platform.isAndroid) {
    yield const WatchDownloads();
    return;
  }
  final events = StreamController<void>();
  var disposed = false;
  void changed() {
    if (!disposed) events.add(null);
  }

  final lifecycle = AppLifecycleListener(onResume: changed);
  final native = const EventChannel('medito.app/watch/downloads')
      .receiveBroadcastStream()
      .listen(
        (_) => changed(),
        onError: (Object error) {
          if (!disposed) events.addError(error);
        },
      );
  ref.onDispose(() {
    disposed = true;
    lifecycle.dispose();
    native.cancel();
    events.close();
  });
  final service = ref.read(watchDownloadServiceProvider);
  yield await service.refresh();
  await for (final _ in events.stream) {
    yield await service.refresh();
  }
});

final watchDownloadServiceProvider = Provider(
  (ref) => WatchDownloadService(ref),
);

class WatchDownloads {
  const WatchDownloads({
    this.available = false,
    this.items = const [],
    this.updatedAt,
  });
  final bool available;
  final List<Map<String, dynamic>> items;
  final DateTime? updatedAt;

  factory WatchDownloads.fromMap(Map<dynamic, dynamic> map) => WatchDownloads(
    available: map['available'] == true,
    items: (map['items'] as List? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(),
    updatedAt: map['updatedAt'] is num
        ? DateTime.fromMillisecondsSinceEpoch((map['updatedAt'] as num).toInt())
        : null,
  );
}

class WatchDownloadService {
  WatchDownloadService(this.ref);
  final Ref ref;
  static const channel = MethodChannel('medito.app/watch');

  Future<WatchDownloads> refresh() async {
    try {
      return WatchDownloads.fromMap(
        await channel.invokeMapMethod('downloadsGet') ?? {},
      );
    } on MissingPluginException {
      return const WatchDownloads();
    }
  }

  Future<void> send(Track track) async {
    final voice = track.voices.first;
    final file = voice.audioFiles.first;
    final name = '${track.id}-${file.id}${getAudioFileExtension(file.path)}';
    final path = await ref
        .read(downloaderRepositoryProvider)
        .getDownloadedFile(name);
    if (path == null) throw PlatformException(code: 'missing_download');
    await channel.invokeMethod('downloadsSend', {
      'id': track.id,
      'fileId': file.id,
      'title': track.title,
      'audioUrl': file.path,
      'coverUrl': track.coverUrl,
      'guide': voice.guideName ?? '',
      'durationMs': file.duration,
      'path': path,
      'bytes': await File(path).length(),
    });
    if (ref.mounted) ref.invalidate(watchDownloadsProvider);
  }

  Future<void> remove(Map<String, dynamic> item) async {
    await channel.invokeMethod('downloadsRemove', item);
    if (ref.mounted) ref.invalidate(watchDownloadsProvider);
  }
}
