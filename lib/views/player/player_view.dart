import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/view_model/audio_player/audio_player_viewmodel.dart';
import 'package:Medito/view_model/background_sounds/background_sounds_viewmodel.dart';
import 'package:Medito/view_model/player/download/audio_downloader_viewmodel.dart';
import 'package:Medito/view_model/player/audio_play_pause_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'components/artist_title_component.dart';
import 'components/background_image_component.dart';
import 'components/bottom_actions/bottom_action_component.dart';
import 'components/duration_indicator_component.dart';
import 'components/overlay_cover_image_component.dart';
import 'components/player_buttons_component.dart';

class PlayerView extends ConsumerStatefulWidget {
  const PlayerView({super.key, required this.sessionModel, required this.file});
  final SessionModel sessionModel;
  final SessionFilesModel file;
  @override
  ConsumerState<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends ConsumerState<PlayerView> {
  late int sessionId, fileId;
  @override
  void initState() {
    sessionId = widget.sessionModel.id;
    fileId = widget.file.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkAudioLocally();
    });
    super.initState();
  }

  void checkAudioLocally() {
    loadSessionAndBackgroundSound();
    ref.read(audioPlayPauseStateProvider.notifier).state =
        PLAY_PAUSE_AUDIO.PLAY;
  }

  void loadSessionAndBackgroundSound() {
    final _audioPlayerNotifier = ref.read(audioPlayerNotifierProvider);
    var isPlaying = _audioPlayerNotifier.sessionAudioPlayer.playerState.playing;
    var _currentPlayingFileId =
        _audioPlayerNotifier.currentlyPlayingSession?.id;

    if (!isPlaying || _currentPlayingFileId != fileId) {
      setSessionAudio(_audioPlayerNotifier);
      setBackgroundSound(_audioPlayerNotifier);
    }
  }

  void setSessionAudio(AudioPlayerNotifier audioPlayerNotifier) {
    var checkDownloadedFile = ref.read(audioDownloaderProvider).getSessionAudio(
          '$sessionId-$fileId${getFileExtension(widget.file.path)}',
        );
    checkDownloadedFile.then((value) {
      audioPlayerNotifier.setSessionAudio(widget.file, filePath: value);
      audioPlayerNotifier.currentlyPlayingSession = widget.file;
    });
  }

  void setBackgroundSound(AudioPlayerNotifier audioPlayerNotifier) {
    if (widget.sessionModel.hasBackgroundSound) {
      final _provider = ref.read(backgroundSoundsNotifierProvider);
      _provider.getBackgroundSoundFromPref().then((_) {
        if (_provider.selectedBgSound != null &&
            _provider.selectedBgSound?.title != StringConstants.NONE) {
          audioPlayerNotifier.setBackgroundAudio(_provider.selectedBgSound!);
        }
      });
      _provider.getVolumeFromPref().then((_) {
        audioPlayerNotifier.setBackgroundSoundVolume(_provider.volume);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var coverUrl = widget.sessionModel.coverUrl;

    return Scaffold(
      extendBody: false,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          BackgroundImageComponent(imageUrl: coverUrl),
          SafeArea(
            child: Column(
              children: [
                Container(
                  height: 4,
                  width: 44,
                  decoration: BoxDecoration(
                    color: ColorConstants.walterWhite,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                Spacer(),
                ArtistTitleComponent(sessionModel: widget.sessionModel),
                OverlayCoverImageComponent(imageUrl: coverUrl),
                DurationIndicatorComponent(file: widget.file),
                Spacer(),
                PlayerButtonsComponent(
                  file: widget.file,
                  sessionModel: widget.sessionModel,
                ),
                Spacer(),
                BottomActionComponent(
                  sessionModel: widget.sessionModel,
                  file: widget.file,
                ),
                height16,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
