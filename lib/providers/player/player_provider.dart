import 'package:Medito/models/models.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final playerProvider =
    StateNotifierProvider<PlayerProvider, MeditationModel?>((ref) {
  return PlayerProvider(ref);
});

class PlayerProvider extends StateNotifier<MeditationModel?> {
  PlayerProvider(this.ref) : super(null);
  Ref ref;
  Future<void> addCurrentlyPlayingMeditationInPreference({
    required MeditationModel meditationModel,
    required MeditationFilesModel file,
  }) async {
    var _meditation = meditationModel.customCopyWith();
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

    state = _meditation;
    await ref
        .read(meditationRepositoryProvider)
        .addCurrentlyPlayingMeditationInPreference(_meditation);
  }

  void getCurrentlyPlayingMeditation() {
    ref
        .read(meditationRepositoryProvider)
        .fetchCurrentlyPlayingMeditationFromPreference()
        .then(
          (value) => state = value,
        );
  }
}
