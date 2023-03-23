import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/session/session_model.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/view_model/background_sounds/background_sounds_viewmodel.dart';
import 'package:Medito/view_model/page_view/page_view_viewmodel.dart';
import 'package:Medito/view_model/player/download/audio_downloader_viewmodel.dart';
import 'package:Medito/view_model/player/player_viewmodel.dart';
import 'package:Medito/views/player/player_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'view_model/audio_player/audio_player_viewmodel.dart';
import 'view_model/player/audio_play_pause_viewmodel.dart';
import 'views/player/components/mini_player_widget.dart';

class RootPageView extends ConsumerStatefulWidget {
  final Widget firstChild;

  RootPageView({required this.firstChild});
  @override
  ConsumerState<RootPageView> createState() => _RootPageViewtState();
}

class _RootPageViewtState extends ConsumerState<RootPageView> {
  @override
  void initState() {
    ref.read(playerProvider.notifier).getCurrentlyPlayingSession();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final currentlyPlayingSession = ref.watch(playerProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentlyPlayingSession != null) {
        checkAudioLocally(currentlyPlayingSession,
            currentlyPlayingSession.audio.first.files.first);
      }
    });
    return Scaffold(
      backgroundColor: ColorConstants.greyIsTheNewGrey,
      body: PageView(
        controller: ref.read(pageviewNotifierProvider).pageController,
        scrollDirection: Axis.vertical,
        // physics: BouncingScrollPhysics(),
        children: [
          Column(
            children: [
              Expanded(child: widget.firstChild),
              if (currentlyPlayingSession != null)
                MiniPlayerWidget(
                  sessionModel: currentlyPlayingSession,
                )
            ],
          ),
          if (currentlyPlayingSession != null)
            PlayerView(
                sessionModel: currentlyPlayingSession,
                file: currentlyPlayingSession.audio.first.files.first)
        ],
      ),
    );
  }

  void checkAudioLocally(SessionModel sessionModel, SessionFilesModel file) {
    loadSessionAndBackgroundSound(sessionModel, file);
    // ref.read(audioPlayPauseStateProvider.notifier).state =
    //     PLAY_PAUSE_AUDIO.PLAY;
  }

  void loadSessionAndBackgroundSound(
      SessionModel sessionModel, SessionFilesModel file) {
    final _audioPlayerNotifier = ref.read(audioPlayerNotifierProvider);
    var isPlaying = _audioPlayerNotifier.sessionAudioPlayer.playerState.playing;
    var _currentPlayingFileId =
        _audioPlayerNotifier.currentlyPlayingSession?.id;

    if (!isPlaying || _currentPlayingFileId != file.id) {
      setSessionAudio(_audioPlayerNotifier, sessionModel, file);
      setBackgroundSound(_audioPlayerNotifier, sessionModel.hasBackgroundSound);
    }
  }

  void setSessionAudio(AudioPlayerNotifier _audioPlayerNotifier,
      SessionModel sessionModel, SessionFilesModel file) {
    var checkDownloadedFile = ref.read(audioDownloaderProvider).getSessionAudio(
        '${sessionModel.id}-${file.id}${getFileExtension(file.path)}');
    checkDownloadedFile.then((value) {
      _audioPlayerNotifier.setSessionAudio(file, filePath: value);
      _audioPlayerNotifier.currentlyPlayingSession = file;
    });
  }

  void setBackgroundSound(
      AudioPlayerNotifier _audioPlayerNotifier, bool hasBackgroundSound) {
    if (hasBackgroundSound) {
      final _provider = ref.read(backgroundSoundsNotifierProvider);
      _provider.getBackgroundSoundFromPref().then((_) {
        if (_provider.selectedBgSound != null &&
            _provider.selectedBgSound?.title != StringConstants.NONE) {
          _audioPlayerNotifier.setBackgroundAudio(_provider.selectedBgSound!);
        }
      });
      _provider.getVolumeFromPref().then((_) {
        _audioPlayerNotifier.setBackgroundSoundVolume(_provider.volume);
      });
    }
  }
}
