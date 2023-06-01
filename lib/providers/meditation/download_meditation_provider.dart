import 'dart:async';
import 'package:Medito/models/models.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'meditation_provider.dart';
part 'download_meditation_provider.g.dart';

@riverpod
Future<List<MeditationModel>> downloadedMeditations(ref) {
  return ref
      .watch(meditationRepositoryProvider)
      .fetchMeditationFromPreference();
}

@riverpod
Future<void> deleteMeditationFromPreference(
  ref, {
  required MeditationFilesModel file,
}) async {
  var _downloadedMeditationList =
      await ref.read(downloadedMeditationsProvider.future);
  _downloadedMeditationList.removeWhere((element) =>
      element.audio.first.files.indexWhere((e) => e.id == file.id) != -1);
  await ref.read(
    addMeditationListInPreferenceProvider(
      meditations: _downloadedMeditationList,
    ).future,
  );
  unawaited(ref.refresh(downloadedMeditationsProvider.future));
}
