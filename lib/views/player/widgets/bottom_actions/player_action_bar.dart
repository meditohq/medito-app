import 'package:flutter/material.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/main.dart';
import 'package:medito/models/track/track_model.dart';
import 'package:medito/views/player/widgets/bottom_actions/widgets/audio_download_widget.dart';
import 'package:medito/views/player/widgets/bottom_actions/widgets/audio_speed_widget.dart';
import 'package:medito/views/player/widgets/bottom_actions/widgets/bg_sound_widget.dart';

import 'bottom_action_bar.dart';

class PlayerActionBar extends StatelessWidget {
  const PlayerActionBar({
    super.key,
    required this.trackModel,
    required this.file,
    required this.isBackgroundSoundSelected,
    required this.onSpeedChanged,
    required this.onClosePressed,
  });

  final bool isBackgroundSoundSelected;
  final TrackModel trackModel;
  final TrackFilesModel file;
  final Function(double) onSpeedChanged;
  final VoidCallback onClosePressed;

  @override
  Widget build(BuildContext context) {
    return BottomActionBar(
      showBackground: true,
      actions: [
        _buildCloseButton(),
        _buildAudioDownloadWidget(),
        _buildBackgroundSoundWidget(),
        _buildAudioSpeedWidget(),
      ],
    );
  }

  Widget _buildCloseButton() {
    return GestureDetector(
      onTap: onClosePressed,
      child: const Icon(
        Icons.close,
        color: ColorConstants.walterWhite,
      ),
    );
  }

  Widget _buildAudioDownloadWidget() {
    return AudioDownloadWidget(
      trackModel: trackModel,
      file: file,
    );
  }

  Widget _buildBackgroundSoundWidget() {
    return trackModel.hasBackgroundSound
        ? BgSoundWidget(
            isBackgroundSoundSelected: isBackgroundSoundSelected,
            trackModel: trackModel,
            file: file,
          )
        : _buildDisabledBackgroundSoundIcon();
  }

  Widget _buildDisabledBackgroundSoundIcon() {
    return GestureDetector(
      onTap: _showBackgroundSoundDisabledMessage,
      child: const Icon(
        Icons.music_off,
        color: ColorConstants.walterWhite,
      ),
    );
  }

  void _showBackgroundSoundDisabledMessage() {
    scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text(StringConstants.backgroundSoundsDisabled),
      ),
    );
  }

  Widget _buildAudioSpeedWidget() {
    return AudioSpeedWidget(onSpeedChanged: onSpeedChanged);
  }
}
