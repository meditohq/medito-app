import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:medito/services/network/download_service.dart';
import 'package:medito/src/download_all_pigeon.g.dart';
import 'package:medito/utils/logger.dart';
import 'package:path_provider/path_provider.dart';

class BatchDownloadItem {
  final String url;
  final String fileName;
  final String trackId;
  final String fileId;

  const BatchDownloadItem({
    required this.url,
    required this.fileName,
    required this.trackId,
    required this.fileId,
  });

  Map<String, dynamic> toJson() => {
        'url': url,
        'fileName': fileName,
        'trackId': trackId,
        'fileId': fileId,
      };

  factory BatchDownloadItem.fromJson(Map<String, dynamic> json) =>
      BatchDownloadItem(
        url: json['url'] as String,
        fileName: json['fileName'] as String,
        trackId: json['trackId'] as String,
        fileId: json['fileId'] as String,
      );
}

class BatchDownloadProgress {
  final int completed;
  final int total;
  final bool isRunning;

  const BatchDownloadProgress({
    required this.completed,
    required this.total,
    required this.isRunning,
  });
}

class BatchDownloadService {
  final DownloadAllHostApi _hostApi;
  final DownloadService _downloadService;
  bool _isCancelled = false;

  BatchDownloadService({
    DownloadAllHostApi? hostApi,
    DownloadService? downloadService,
  })  : _hostApi = hostApi ?? DownloadAllHostApi(),
        _downloadService = downloadService ?? DownloadService();

  /// Removes leftover partial files from interrupted downloads.
  Future<void> cleanupPartFiles() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final entities = docDir.listSync();
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.part')) {
          await entity.delete();
        }
      }
    } catch (e) {
      AppLogger.e('BATCH_DOWNLOAD', 'Failed to cleanup part files: $e');
    }
  }

  /// Initiates concurrent downloading of items with atomic completion.
  /// On Android, executes in a foreground service via Pigeon.
  /// On other platforms, executes concurrently in Dart with a pool of 4.
  Future<void> downloadBatch(
    List<BatchDownloadItem> items, {
    void Function(BatchDownloadProgress progress)? onProgress,
  }) async {
    if (items.isEmpty) return;
    _isCancelled = false;
    await cleanupPartFiles();

    if (!kIsWeb && Platform.isAndroid) {
      await _downloadBatchAndroid(items, onProgress: onProgress);
    } else {
      await _downloadBatchDart(items, onProgress: onProgress);
    }
  }

  Future<void> _downloadBatchAndroid(
    List<BatchDownloadItem> items, {
    void Function(BatchDownloadProgress progress)? onProgress,
  }) async {
    final docDir = await getApplicationDocumentsDirectory();
    final manifestFile = File('${docDir.path}/batch_download_manifest.json');
    final jsonContent = jsonEncode(items.map((i) => i.toJson()).toList());
    await manifestFile.writeAsString(jsonContent);

    try {
      await _hostApi.startBatch(manifestFile.path);

      while (!_isCancelled) {
        await Future.delayed(const Duration(milliseconds: 500));
        final status = await _hostApi.getStatus();
        onProgress?.call(
          BatchDownloadProgress(
            completed: status.completed,
            total: status.total,
            isRunning: status.isRunning,
          ),
        );
        if (!status.isRunning) {
          break;
        }
      }
    } catch (e) {
      AppLogger.e('BATCH_DOWNLOAD', 'Android native batch download error: $e');
      // If native host API isn't registered, fall back to Dart concurrent execution
      await _downloadBatchDart(items, onProgress: onProgress);
    } finally {
      if (await manifestFile.exists()) {
        try {
          await manifestFile.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> _downloadBatchDart(
    List<BatchDownloadItem> items, {
    void Function(BatchDownloadProgress progress)? onProgress,
  }) async {
    final docDir = await getApplicationDocumentsDirectory();
    final total = items.length;
    var completed = 0;
    var currentIndex = 0;

    onProgress?.call(
      BatchDownloadProgress(
        completed: 0,
        total: total,
        isRunning: true,
      ),
    );

    const maxConcurrency = 4;

    Future<void> worker() async {
      while (!_isCancelled) {
        if (currentIndex >= items.length) {
          return;
        }
        final item = items[currentIndex++];

        final targetPath = '${docDir.path}/${item.fileName}';
        final file = File(targetPath);
        if (await file.exists() && await file.length() > 0) {
          completed++;
          onProgress?.call(
            BatchDownloadProgress(
              completed: completed,
              total: total,
              isRunning: true,
            ),
          );
          continue;
        }

        try {
          await _downloadService.downloadFile(item.url, targetPath);
          completed++;
          onProgress?.call(
            BatchDownloadProgress(
              completed: completed,
              total: total,
              isRunning: true,
            ),
          );
        } catch (e) {
          AppLogger.e('BATCH_DOWNLOAD', 'Download failed for ${item.fileName}: $e');
        }
      }
    }

    final workers = List.generate(maxConcurrency, (_) => worker());
    await Future.wait(workers);

    onProgress?.call(
      BatchDownloadProgress(
        completed: completed,
        total: total,
        isRunning: false,
      ),
    );
  }

  Future<void> stopBatch() async {
    _isCancelled = true;
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _hostApi.stopBatch();
      } catch (e) {
        AppLogger.e('BATCH_DOWNLOAD', 'Error calling stopBatch: $e');
      }
    }
    await cleanupPartFiles();
  }
}
