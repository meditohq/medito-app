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
Future<SessionModel?> getSpecificSessions(GetSpecificSessionsRef ref,
    {required int sessionId, required int fileId}) async {
  var sessions = await ref.watch(downloadedSessionsProvider.future);
  SessionModel? foundSession;
  for (var i = 0; i < sessions.length; i++) {
    var element = sessions[i];
    if (element.id == sessionId) {
      var fileIndex = element.audio.first.files
          .indexWhere((element) => element.id == fileId);
      if (fileIndex != -1) {
        foundSession = element;
        break;
      }
    }
  }
  return foundSession;
}

@riverpod
Future<void> addSessionInPreference(AddSessionInPreferenceRef ref,
    {required SessionModel sessionModel,
    required SessionFilesModel file}) async {
  for (var i = 0; i < sessionModel.audio.length; i++) {
    var element = sessionModel.audio[i];
    var fileIndex = element.files.indexWhere((e) => e.id == file.id);
    if (fileIndex != -1) {
      sessionModel.audio.removeWhere((e) => e.guideName != element.guideName);
      sessionModel.audio[i].files
          .removeWhere((e) => e.id != element.files[fileIndex].id);
      break;
    }
  }
  var _downloadedSessionList =
      await ref.read(downloadedSessionsProvider.future);
  _downloadedSessionList.add(sessionModel);
  await ref
      .read(sessionRepositoryProvider)
      .addSessionInPreference(_downloadedSessionList);
}
