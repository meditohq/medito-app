import 'dart:async';
import 'package:Medito/models/models.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'session_provider.dart';
part 'download_session_provider.g.dart';

@riverpod
Future<List<SessionModel>> downloadedSessions(ref) {
  return ref.watch(sessionRepositoryProvider).fetchSessionFromPreference();
}

@riverpod
Future<void> deleteSessionFromPreference(
  ref, {
  required SessionFilesModel file,
}) async {
  var _downloadedSessionList =
      await ref.read(downloadedSessionsProvider.future);
  _downloadedSessionList.removeWhere((element) =>
      element.audio.first.files.indexWhere((e) => e.id == file.id) != -1);
  await ref.read(
    addSessionListInPreferenceProvider(sessions: _downloadedSessionList).future,
  );
  unawaited(ref.refresh(downloadedSessionsProvider.future));
}
