import 'package:Medito/models/models.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final playerProvider =
    StateNotifierProvider<PlayerProvider, SessionModel?>((ref) {
  return PlayerProvider(ref);
});

class PlayerProvider extends StateNotifier<SessionModel?> {
  PlayerProvider(this.ref) : super(null);
  Ref ref;
  Future<void> addCurrentlyPlayingSessionInPreference({
    required SessionModel sessionModel,
    required SessionFilesModel file,
  }) async {
    var _session = sessionModel.customCopyWith();
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

    state = _session;
    await ref
        .read(sessionRepositoryProvider)
        .addCurrentlyPlayingSessionInPreference(_session);
  }

  void getCurrentlyPlayingSession() {
    ref
        .read(sessionRepositoryProvider)
        .fetchCurrentlyPlayingSessionFromPreference()
        .then(
          (value) => state = value,
        );
  }
}
