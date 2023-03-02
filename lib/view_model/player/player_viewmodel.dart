import 'package:Medito/view_model/audio_player/audio_player_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'player_viewmodel.g.dart';

@riverpod
bool playPauseAudio(
  PlayPauseAudioRef ref, {
  required PLAY_PAUSE_AUDIO action,
}) {
  final audioPlayer = ref.watch(audioPlayerNotifierProvider);
  switch (action) {
    case PLAY_PAUSE_AUDIO.PLAY:
      audioPlayer.playSessionAudio();
      break;
    case PLAY_PAUSE_AUDIO.PAUSE:
      audioPlayer.pauseSessionAudio();
      break;
  }
  return audioPlayer.sessionAudioPlayer.playerState.playing;
}

final playerProvider = ChangeNotifierProvider<PlayerViewModel>((ref) {
  return PlayerViewModel(ref);
});

class PlayerViewModel extends ChangeNotifier {
  ChangeNotifierProviderRef<PlayerViewModel> ref;
  PlayerViewModel(this.ref);
}

enum PLAY_PAUSE_AUDIO { PLAY, PAUSE }



  // double downloadingProgress = 0.0;

  // Future<void> downloadSessionAudio(String url, {String? fileName}) async {
  //   try {
  //     final downloadAudio = ref.read(downloaderRepositoryProvider);
  //     await downloadAudio.downloadFile(
  //       url,
  //       name: fileName,
  //       onReceiveProgress: (received, total) {
  //         if (total != -1) {
  //           downloadingProgress = (received / total * 100);
  //           // (received / total * 100).toStringAsFixed(0) + '%';
  //           print(downloadingProgress);
  //           notifyListeners();
  //         }
  //       },
  //     );
  //   } catch (e) {
  //     rethrow;
  //   }
  // }