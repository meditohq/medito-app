import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/routes/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

final rootCombineProvider = Provider.family<void, BuildContext>((ref, context) {
  var audioPlayerProvider = ref.read(audioPlayerNotifierProvider);
  audioPlayerProvider.initAudioHandler();
  ref.read(remoteStatsProvider);
  ref.read(authProvider.notifier).saveFcmTokenEvent();
  ref.read(postLocalStatsProvider);
  ref.read(deviceAppAndUserInfoProvider);
  ref.read(audioDownloaderProvider).deleteDownloadedFileFromPreviousVersion();

  var streamEvent = audioPlayerProvider.trackAudioPlayer.playerStateStream
      .map((event) => event.processingState)
      .distinct();
  streamEvent.forEach((element) {
    if (element == ProcessingState.completed) {
      _handleAudioCompletion(ref, context);
      _handleUserNotSignedIn(ref, context);
    }
  });
});

void _handleAudioCompletion(Ref ref, BuildContext context) {
  final audioProvider = ref.read(audioPlayerNotifierProvider);
  var extras = audioProvider.mediaItem.value?.extras;
  if (extras != null) {
    ref.read(playerProvider.notifier).handleAudioCompletionEvent(
          extras[TypeConstants.fileIdKey],
          extras[TypeConstants.trackIdKey],
        );

    audioProvider.seekValueFromSlider(0);
    audioProvider.pause();
    audioProvider.setBackgroundSoundVolume(audioProvider.bgVolume);
    audioProvider.stop();
    ref.invalidate(packProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioPlayPauseStateProvider.notifier).state =
          PLAY_PAUSE_AUDIO.PAUSE;
    });
    var currentlyPlayingTrack = ref.read(playerProvider);
    var endScreen = currentlyPlayingTrack?.endScreen;
    if (endScreen != null) {
      context.push(RouteConstants.endScreenPath, extra: endScreen);
    }
  }
}

void _handleUserNotSignedIn(Ref ref, BuildContext context) {
  var _user =
      ref.read(authProvider.notifier).userResponse.body as UserTokenModel;
  if (_user.email == null) {
    var params = JoinRouteParamsModel(screen: Screen.track);
    context.push(
      RouteConstants.joinIntroPath,
      extra: params,
    );
  }
}
