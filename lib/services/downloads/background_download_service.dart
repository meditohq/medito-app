import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:medito/models/player/playback_request.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/utils/utils.dart';

abstract class AutomaticDownloadQueue {
  Future<void> get ready;
  Future<void> enqueue(PlaybackRequest request, {required bool requiresWiFi});
  Future<void> configure({required bool enabled, required bool requiresWiFi});
  Future<void> cancelExcept(String? trackId, {String? fileId});
  Future<void> resume();
  bool owns(String fileName);
  void dispose();
}

/// Native URLSession downloads on iOS and persistent WorkManager jobs on
/// Android. The task metadata survives Dart/process death along with the file.
class BackgroundDownloadService implements AutomaticDownloadQueue {
  BackgroundDownloadService({
    required this.downloader,
    required this.onCompleted,
    required this.onStatus,
    required bool enabled,
    required bool requiresWiFi,
    Future<bool> Function(Task)? fileExists,
  }) : _enabled = enabled,
       _requiresWiFi = requiresWiFi,
       _fileExists = fileExists ?? _downloadedFileExists {
    ready = _initialize();
  }

  static const group = 'automaticSessions';
  final FileDownloader downloader;
  final Future<void> Function(PlaybackRequest) onCompleted;
  final void Function(PlaybackRequest, TaskStatus, double?) onStatus;
  final Future<bool> Function(Task) _fileExists;
  static Future<bool> _downloadedFileExists(Task task) async =>
      File(await task.filePath()).exists();
  @override
  late final Future<void> ready;
  final Map<String, DownloadTask> _pending = {};
  final Set<String> _retiredTaskIds = {};
  Future<void> _operations = Future.value();
  StreamSubscription<TaskRecord>? _records;
  Timer? _recovery;
  bool _enabled;
  bool _requiresWiFi;
  bool _disposed = false;

  static String fileName(PlaybackRequest request) =>
      '${request.trackId}-${request.fileId}${getAudioFileExtension(request.remoteUrl)}';

  PlaybackRequest _request(Task task) => PlaybackRequest.fromJson(
    jsonDecode(task.metaData) as Map<String, dynamic>,
  );

  Future<void> _initialize() async {
    downloader.registerCallbacks(
      group: group,
      taskStatusCallback: (update) {
        if (_disposed ||
            update.task is! DownloadTask ||
            _retiredTaskIds.contains(update.task.taskId)) {
          return;
        }
        final task = update.task as DownloadTask;
        if (!update.status.isFinalState) {
          _pending[task.taskId] = task;
        }
        // A late cancellation from a replaced task must not reset its successor.
        if (_pending.containsKey(task.taskId)) {
          onStatus(_request(task), update.status, null);
          if (update.status.isFinalState) _pending.remove(task.taskId);
        }
      },
      taskProgressCallback: (update) {
        if (!_disposed &&
            _pending.containsKey(update.task.taskId) &&
            update.progress >= 0) {
          onStatus(_request(update.task), TaskStatus.running, update.progress);
        }
      },
    );
    // Database notifications follow the plugin's persisted status write.
    // Acknowledge only AFTER the completed file is saved in our Downloads list.
    _records = downloader.database.updates.listen((record) {
      if (record.group == group && record.status == TaskStatus.complete) {
        unawaited(_serial(() => _importCompleted(record)));
      }
    });
    await downloader.trackTasksInGroup(group, markDownloadedComplete: true);
    await downloader.resumeFromBackground();
    for (final record in await downloader.database.allRecords(group: group)) {
      if (record.task is! DownloadTask) continue;
      final task = record.task as DownloadTask;
      if (record.status == TaskStatus.complete) {
        await _serial(() => _importCompleted(record));
      } else if (!record.status.isFinalState) {
        _pending[task.taskId] = task;
      }
    }
    await _applyConfiguration();
    // Give replayed native events time to land before identifying lost tasks.
    _recovery = Timer(const Duration(seconds: 5), () {
      unawaited(
        _serial(() async {
          if (_enabled && !_disposed) await downloader.rescheduleKilledTasks();
        }),
      );
    });
  }

  Future<void> _serial(Future<void> Function() action) {
    final next = _operations.then((_) async {
      if (!_disposed) await action();
    });
    _operations = next.catchError((Object error) {
      AppLogger.e(
        'BACKGROUND_DOWNLOAD',
        'Could not update queued session',
        error,
      );
    });
    return next;
  }

  Future<void> _importCompleted(TaskRecord record) async {
    // Repeated callbacks after an acknowledgement must not resurrect a file
    // the user has since removed. Check the authoritative record again.
    final current = await downloader.database.recordForId(record.taskId);
    if (current?.status != TaskStatus.complete) return;
    if (_retiredTaskIds.contains(record.taskId)) {
      await downloader.database.deleteRecordWithId(record.taskId);
      return;
    }
    if (await _fileExists(record.task)) {
      await onCompleted(_request(record.task));
    }
    await downloader.database.deleteRecordWithId(record.taskId);
    _pending.remove(record.taskId);
  }

  @override
  bool owns(String fileName) =>
      _pending.values.any((task) => task.filename == fileName);

  @override
  Future<void> configure({
    required bool enabled,
    required bool requiresWiFi,
  }) async {
    _enabled = enabled;
    _requiresWiFi = requiresWiFi;
    await ready;
    await _serial(_applyConfiguration);
  }

  Future<void> _applyConfiguration() async {
    for (final task in _pending.values.toList()) {
      if (!_enabled || task.requiresWiFi != _requiresWiFi) {
        _pending.remove(task.taskId);
        _retiredTaskIds.add(task.taskId);
        await downloader.cancelTaskWithId(task.taskId);
        await downloader.database.deleteRecordWithId(task.taskId);
        onStatus(_request(task), TaskStatus.canceled, null);
        if (_enabled) {
          await _enqueue(_request(task), requiresWiFi: _requiresWiFi);
        }
      }
    }
  }

  @override
  Future<void> enqueue(
    PlaybackRequest request, {
    required bool requiresWiFi,
  }) async {
    await ready;
    await _serial(() => _enqueue(request, requiresWiFi: requiresWiFi));
  }

  Future<void> _enqueue(
    PlaybackRequest request, {
    required bool requiresWiFi,
  }) async {
    // Settings can change while an older reconciliation waits in this queue.
    // Never let that stale request relax the user's current network policy.
    if (!_enabled || _disposed || requiresWiFi != _requiresWiFi) return;
    final name = fileName(request);
    if (_pending.values.any((task) => task.filename == name)) return;
    final task = DownloadTask(
      url: request.remoteUrl,
      filename: name,
      baseDirectory: BaseDirectory.applicationDocuments,
      group: group,
      requiresWiFi: requiresWiFi,
      allowPause: true,
      retries: 3,
      updates: Updates.statusAndProgress,
      metaData: jsonEncode(request.toJson()),
      displayName: request.title,
    );
    if (await _fileExists(task)) {
      await onCompleted(request);
      return;
    }
    _pending[task.taskId] = task;
    if (!await downloader.enqueue(task)) {
      _pending.remove(task.taskId);
      throw StateError('The phone could not queue the session download');
    }
  }

  @override
  Future<void> cancelExcept(String? trackId, {String? fileId}) async {
    await ready;
    await _serial(() async {
      for (final task in _pending.values.toList()) {
        final request = _request(task);
        if (request.trackId == trackId &&
            (fileId == null || request.fileId == fileId)) {
          continue;
        }
        _pending.remove(task.taskId);
        _retiredTaskIds.add(task.taskId);
        await downloader.cancelTaskWithId(task.taskId);
        await downloader.database.deleteRecordWithId(task.taskId);
        onStatus(_request(task), TaskStatus.canceled, null);
      }
    });
  }

  @override
  Future<void> resume() async {
    await ready;
    await downloader.resumeFromBackground();
    for (final record in await downloader.database.allRecords(group: group)) {
      if (record.status == TaskStatus.complete) {
        await _serial(() => _importCompleted(record));
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _recovery?.cancel();
    unawaited(_records?.cancel());
    downloader.unregisterCallbacks(group: group);
    // Native transfers deliberately outlive the Dart provider/process.
  }
}
