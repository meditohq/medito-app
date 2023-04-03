import 'package:Medito/models/models.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'session_viewmodel.g.dart';

@riverpod
Future<SessionModel> sessions(
  SessionsRef ref, {
  required int sessionId,
}) {
  return ref.watch(sessionRepositoryProvider).fetchSession(sessionId);
}

@riverpod
Future<List<SessionModel>> downloadedSessions(DownloadedSessionsRef ref) {
  return ref.watch(sessionRepositoryProvider).fetchSessionFromPreference();
}

@riverpod
Future<void> addSessionListInPreference(
  AddSessionListInPreferenceRef ref, {
  required List<SessionModel> sessions,
}) async {
  return await ref
      .read(sessionRepositoryProvider)
      .addSessionInPreference(sessions);
}

@riverpod
Future<void> addSingleSessionInPreference(
  AddSingleSessionInPreferenceRef ref, {
  required SessionModel sessionModel,
  required SessionFilesModel file,
}) async {
  var _session = sessionModel.customCopyWith();
  print(sessionModel == _session);
  print(sessionModel.audio == _session.audio);
  for (var i = 0; i < _session.audio.length; i++) {
    var element = _session.audio[i];
    var fileIndex = element.files.indexWhere((e) => e.id == file.id);
    if (fileIndex != -1) {
      _session.audio.removeWhere((e) => e.guideName != element.guideName);
      _session.audio.first.files
          .removeWhere((e) => e.id != element.files[fileIndex].id);
      break;
    }
  }
  var _downloadedSessionList =
      await ref.read(downloadedSessionsProvider.future);
  _downloadedSessionList.add(_session);
  await ref.read(
    addSessionListInPreferenceProvider(sessions: _downloadedSessionList).future,
  );
}

@riverpod
Future<void> addCurrentlyPlayingSessionInPreference(ref,
    {required SessionModel sessionModel,
    required SessionFilesModel file}) async {
  var _session = sessionModel.customCopyWith();
  print(sessionModel == _session);
  print(sessionModel.audio == _session.audio);
  for (var i = 0; i < _session.audio.length; i++) {
    var element = _session.audio[i];
    var fileIndex = element.files.indexWhere((e) => e.id == file.id);
    if (fileIndex != -1) {
      _session.audio.removeWhere((e) => e.guideName != element.guideName);
      _session.audio.first.files
          .removeWhere((e) => e.id != element.files[fileIndex].id);
      break;
    }
  }
  print(_session);
}

@riverpod
Future<void> deleteSessionFromPreference(ref,
    {required SessionModel sessionModel,
    required SessionFilesModel file}) async {
  var _downloadedSessionList =
      await ref.read(downloadedSessionsProvider.future);
  _downloadedSessionList.removeWhere((element) =>
      element.audio.first.files.indexWhere((e) => e.id == file.id) != -1);
  await ref.read(
    addSessionListInPreferenceProvider(sessions: _downloadedSessionList).future,
  );
}
