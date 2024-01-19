import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/routes/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final rootCombineProvider = Provider.family<void, BuildContext>((ref, context) {
  var audioPlayerProvider = ref.read(audioStateProvider);
  ref.read(remoteStatsProvider);
  ref.read(authProvider.notifier).saveFcmTokenEvent();
  ref.read(postLocalStatsProvider);
  ref.read(deviceAppAndUserInfoProvider);
  ref.read(audioDownloaderProvider).deleteDownloadedFileFromPreviousVersion();

  if (audioPlayerProvider.isCompleted) {
    _handleAudioCompletion(ref, context);
    _handleUserNotSignedIn(ref, context);
  }
});

void _handleAudioCompletion(Ref ref, BuildContext context) {
  final audioProvider = ref.read(audioStateProvider);
  ref.read(playerProvider.notifier).handleAudioCompletionEvent(
    /* extras[TypeConstants.fileIdKey],
          extras[TypeConstants.trackIdKey],*/
    '', '',
  );

  ref.invalidate(packProvider);

  var currentlyPlayingTrack = ref.read(playerProvider);
  var endScreen = currentlyPlayingTrack?.endScreen;
  if (endScreen != null) {
    context.push(RouteConstants.endScreenPath, extra: endScreen);
  }
}

void _handleUserNotSignedIn(Ref ref, BuildContext context) {
  var _user = ref
      .read(authProvider.notifier)
      .userResponse
      .body as UserTokenModel;
  if (_user.email == null) {
    var params = JoinRouteParamsModel(screen: Screen.track);
    context.push(
      RouteConstants.joinIntroPath,
      extra: params,
    );
  }
}
