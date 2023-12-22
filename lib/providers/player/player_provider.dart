import 'dart:async';

import 'package:Medito/models/models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final playerProvider =
    StateNotifierProvider<PlayerProvider, TrackModel?>((ref) {
  return PlayerProvider(ref);
});

class PlayerProvider extends StateNotifier<TrackModel?> {
  PlayerProvider(this.ref) : super(null);
  Ref ref;

  static const _platform = MethodChannel(ChannelConstants.channel);

  Future<void> loadSelectedTrack({
    required TrackModel trackModel,
    required TrackFilesModel file,
  }) async {
    await _platform.invokeMethod(
      ChannelConstants.playUrl,
      {ChannelConstants.url: file.path},
    );
  }

  Future<void> pause() async {
    await _platform.invokeMethod(ChannelConstants.pauseAudio);
  }

  @override
  Future<void> dispose() async {
    await _platform.invokeMethod(ChannelConstants.dispose);
    super.dispose();
  }
}

class ChannelConstants {
  static const String channel = 'meditofoundation.medito/audioplayer';

  static const url = 'url';

  static const playUrl = 'playUrl';

  static const pauseAudio = 'pauseAudio';

  static const dispose = 'dispose';
}
