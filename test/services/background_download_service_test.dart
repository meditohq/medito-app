import 'dart:async';
import 'dart:convert';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/player/playback_request.dart';
import 'package:medito/services/downloads/background_download_service.dart';

class _Database implements Database {
  final records = <String, TaskRecord>{};
  final changes = StreamController<TaskRecord>.broadcast();
  @override
  Stream<TaskRecord> get updates => changes.stream;
  @override
  Future<List<TaskRecord>> allRecords({String? group}) async => records.values
      .where((record) => group == null || record.group == group)
      .toList();
  @override
  Future<TaskRecord?> recordForId(String id) async => records[id];
  @override
  Future<void> deleteRecordWithId(String id) async {
    records.remove(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Downloader implements FileDownloader {
  @override
  final _Database database = _Database();
  TaskStatusCallback? status;
  TaskProgressCallback? progress;
  final enqueued = <DownloadTask>[];
  final canceled = <String>[];
  int recoveries = 0;
  @override
  FileDownloader registerCallbacks({
    String group = FileDownloader.defaultGroup,
    TaskStatusCallback? taskStatusCallback,
    TaskProgressCallback? taskProgressCallback,
    TaskNotificationTapCallback? taskNotificationTapCallback,
  }) {
    status = taskStatusCallback;
    progress = taskProgressCallback;
    return this;
  }

  @override
  FileDownloader unregisterCallbacks({
    String group = FileDownloader.defaultGroup,
    Function? callback,
  }) {
    status = null;
    progress = null;
    return this;
  }

  @override
  Future<FileDownloader> trackTasksInGroup(
    String group, {
    bool markDownloadedComplete = true,
  }) async => this;
  @override
  Future<void> resumeFromBackground() async {}
  @override
  Future<(List<Task>, List<Task>)> rescheduleKilledTasks() async {
    recoveries++;
    return (<Task>[], <Task>[]);
  }

  @override
  Future<bool> enqueue(Task task) async {
    enqueued.add(task as DownloadTask);
    database.records[task.taskId] = TaskRecord(
      task,
      TaskStatus.enqueued,
      0,
      -1,
    );
    status?.call(TaskStatusUpdate(task, TaskStatus.enqueued));
    return true;
  }

  @override
  Future<bool> cancelTaskWithId(String id) async {
    canceled.add(id);
    return true;
  }

  void complete(DownloadTask task) {
    status?.call(TaskStatusUpdate(task, TaskStatus.complete));
    final record = TaskRecord(task, TaskStatus.complete, 1, 100);
    database.records[task.taskId] = record;
    database.changes.add(record);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _request = PlaybackRequest(
  trackId: 'session',
  fileId: 'voice-10',
  title: 'Finding calm',
  description: '',
  coverUrl: '',
  remoteUrl: 'https://example.test/session.mp3',
  duration: 600000,
  hasBackgroundSound: false,
  guideName: 'Will',
);

DownloadTask _task({
  String id = 'persisted',
  PlaybackRequest request = _request,
}) => DownloadTask(
  taskId: id,
  url: request.remoteUrl,
  filename: BackgroundDownloadService.fileName(request),
  group: BackgroundDownloadService.group,
  requiresWiFi: true,
  metaData: jsonEncode(request.toJson()),
);

Future<void> _drain() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

void main() {
  late _Downloader downloader;
  late BackgroundDownloadService service;
  late List<PlaybackRequest> saved;
  late Set<String> files;

  setUp(() {
    downloader = _Downloader();
    saved = [];
    files = {};
  });
  tearDown(() async {
    service.dispose();
    await downloader.database.changes.close();
  });
  Future<void> start({bool enabled = true}) async {
    service = BackgroundDownloadService(
      downloader: downloader,
      enabled: enabled,
      requiresWiFi: true,
      onCompleted: (request) async => saved.add(request),
      onStatus: (_, _, _) {},
      fileExists: (task) async => files.contains(task.filename),
    );
    await service.ready;
  }

  test('queues a persistent native task with exact file location, defaults, and Wi-Fi constraint', () async {
    await start();
    await service.enqueue(_request, requiresWiFi: true);
    final task = downloader.enqueued.single;
    expect(task.baseDirectory, BaseDirectory.applicationDocuments);
    expect(task.directory, '');
    expect(task.filename, 'session-voice-10.mp3');
    expect(task.requiresWiFi, isTrue);
    expect(task.allowPause, isTrue);
    expect(task.retries, 3);
    expect(PlaybackRequest.fromJson(jsonDecode(task.metaData)), _request);
    expect(saved, isEmpty);
    await service.enqueue(_request, requiresWiFi: true);
    expect(downloader.enqueued, hasLength(1));
  });

  test('completed native download is saved before its persistent receipt is acknowledged', () async {
    await start();
    await service.enqueue(_request, requiresWiFi: true);
    final task = downloader.enqueued.single;
    files.add(task.filename);
    downloader.complete(task);
    await _drain();
    expect(saved, [_request]);
    expect(downloader.database.records, isEmpty);
    await service.resume();
    expect(saved, hasLength(1));
  });

  test('reopening imports a task completed while Dart was not running, even with the toggle off', () async {
    final task = _task();
    files.add(task.filename);
    downloader.database.records[task.taskId] = TaskRecord(
      task,
      TaskStatus.complete,
      1,
      100,
    );
    await start(enabled: false);
    expect(saved, [_request]);
    expect(downloader.database.records, isEmpty);
    expect(downloader.enqueued, isEmpty);
  });

  test('a completion receipt with no actual file is discarded without adding a broken download', () async {
    final task = _task();
    downloader.database.records[task.taskId] = TaskRecord(
      task,
      TaskStatus.complete,
      1,
      100,
    );
    await start();
    expect(saved, isEmpty);
    expect(downloader.database.records, isEmpty);
  });

  test(
    'turning off cancels pending audio without deleting completed sessions',
    () async {
      await start();
      await service.enqueue(_request, requiresWiFi: true);
      final task = downloader.enqueued.single;
      await service.configure(enabled: false, requiresWiFi: true);
      expect(downloader.canceled, [task.taskId]);
      expect(downloader.database.records, isEmpty);
      await service.enqueue(_request, requiresWiFi: true);
      expect(downloader.enqueued, hasLength(1));
    },
  );

  test(
    'startup with downloading off cancels tasks left in the native queue',
    () async {
      final task = _task();
      downloader.database.records[task.taskId] = TaskRecord(
        task,
        TaskStatus.enqueued,
        0,
        -1,
      );
      await start(enabled: false);
      expect(downloader.canceled, [task.taskId]);
      expect(downloader.database.records, isEmpty);
    },
  );

  test(
    'changing network policy replaces the pending job with the new constraint',
    () async {
      await start();
      await service.enqueue(_request, requiresWiFi: true);
      final oldId = downloader.enqueued.single.taskId;
      await service.configure(enabled: true, requiresWiFi: false);
      expect(downloader.canceled, [oldId]);
      expect(downloader.enqueued, hasLength(2));
      expect(downloader.enqueued.last.requiresWiFi, isFalse);
      expect(downloader.enqueued.last.taskId, isNot(oldId));
    },
  );

  test(
    'changing Home course or voice cancels the obsolete pending session',
    () async {
      await start();
      await service.enqueue(_request, requiresWiFi: true);
      await service.cancelExcept('session', fileId: 'other-voice');
      expect(downloader.canceled, [downloader.enqueued.single.taskId]);
    },
  );

  test(
    'disposing Dart listeners deliberately leaves native jobs running',
    () async {
      await start();
      await service.enqueue(_request, requiresWiFi: true);
      service.dispose();
      expect(downloader.canceled, isEmpty);
      expect(downloader.database.records, hasLength(1));
    },
  );

  test(
    'a late callback from a replaced job cannot resurrect that job',
    () async {
      await start();
      await service.enqueue(_request, requiresWiFi: true);
      final old = downloader.enqueued.single;
      await service.configure(enabled: true, requiresWiFi: false);
      downloader.status?.call(TaskStatusUpdate(old, TaskStatus.running));
      await service.cancelExcept('another-session');
      expect(downloader.canceled, [
        old.taskId,
        downloader.enqueued.last.taskId,
      ]);
    },
  );

  test(
    'a stale enqueue cannot enable mobile data after Wi-Fi-only was selected',
    () async {
      await start();
      await service.enqueue(_request, requiresWiFi: false);
      expect(downloader.enqueued, isEmpty);
      await service.enqueue(_request, requiresWiFi: true);
      expect(downloader.enqueued.single.requiresWiFi, isTrue);
    },
  );
}
