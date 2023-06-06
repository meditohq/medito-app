import 'dart:async';
import 'package:Medito/models/models.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'download_meditation_provider.dart';
part 'meditation_provider.g.dart';

@riverpod
Future<MeditationModel> meditations(
  ref, {
  required int meditationId,
}) {
  return ref.watch(meditationRepositoryProvider).fetchMeditation(meditationId);
}

@riverpod
Future<void> addMeditationListInPreference(
  ref, {
  required List<MeditationModel> meditations,
}) async {
  return await ref
      .read(meditationRepositoryProvider)
      .addMeditationInPreference(meditations);
}

@riverpod
Future<void> addSingleMeditationInPreference(
  ref, {
  required MeditationModel meditationModel,
  required MeditationFilesModel file,
}) async {
  var _meditation = meditationModel.customCopyWith();
  print(meditationModel == _meditation);
  print(meditationModel.audio == _meditation.audio);
  for (var i = 0; i < _meditation.audio.length; i++) {
    var element = _meditation.audio[i];
    var fileIndex = element.files.indexWhere((e) => e.id == file.id);
    if (fileIndex != -1) {
      _meditation.audio.removeWhere((e) => e.guideName != element.guideName);
      _meditation.audio.first.files
          .removeWhere((e) => e.id != element.files[fileIndex].id);
      break;
    }
  }
  var _downloadedMeditationList =
      await ref.read(downloadedMeditationsProvider.future);
  _downloadedMeditationList.add(_meditation);
  await ref.read(
    addMeditationListInPreferenceProvider(meditations: _downloadedMeditationList).future,
  );
  unawaited(ref.refresh(downloadedMeditationsProvider.future));
}

@riverpod
void addCurrentlyPlayingMeditationInPreference(
  _, {
  required MeditationModel meditationModel,
  required MeditationFilesModel file,
}) {
  var _meditation = meditationModel.customCopyWith();
  print(meditationModel == _meditation);
  print(meditationModel.audio == _meditation.audio);
  for (var i = 0; i < _meditation.audio.length; i++) {
    var element = _meditation.audio[i];
    var fileIndex = element.files.indexWhere((e) => e.id == file.id);
    if (fileIndex != -1) {
      _meditation.audio.removeWhere((e) => e.guideName != element.guideName);
      _meditation.audio.first.files
          .removeWhere((e) => e.id != element.files[fileIndex].id);
      break;
    }
  }
  print(_meditation);
}
