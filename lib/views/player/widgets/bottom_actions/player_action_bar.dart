import 'package:flutter/material.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/scaffold_messenger_key.dart';
import 'package:medito/models/models.dart';
import 'package:medito/views/player/widgets/bottom_actions/widgets/audio_download_widget.dart';
import 'package:medito/views/player/widgets/bottom_actions/widgets/audio_speed_widget.dart';
import 'package:medito/views/player/widgets/bottom_actions/widgets/bg_sound_widget.dart';

import 'bottom_action_bar.dart';

class PlayerActionBar extends StatelessWidget {
  const PlayerActionBar({
    super.key,
    required this.request,
    required this.isBackgroundSoundSelected,
    required this.onSpeedChanged,
    required this.onClosePressed,
  });

  final bool isBackgroundSoundSelected;
  final PlaybackRequest request;
  final Function(double) onSpeedChanged;
  final VoidCallback onClosePressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BottomActionBar(
      layout: BottomActionBarLayout.edgeAligned,
      leftItem: BottomActionBarItem(
        child: const Icon(
          Icons.close,
          color: ColorConstants.white,
        ),
        onTap: onClosePressed,
        semanticLabel: l10n.close,
      ),
      leftCenterItem: BottomActionBarItem(
        child: AudioDownloadWidget(request: request),
        onTap: () {}, // The AudioDownloadWidget handles its own tap
      ),
      rightCenterItem: BottomActionBarItem(
        child: _buildBackgroundSoundWidget(),
        onTap: request.hasBackgroundSound
            ? () {}
            : () => _showBackgroundSoundDisabledMessage(context),
        semanticLabel: l10n.backgroundSounds,
      ),
      rightItem: BottomActionBarItem(
        child: AudioSpeedWidget(onSpeedChanged: onSpeedChanged),
        onTap: () {}, // The AudioSpeedWidget handles its own tap
        semanticLabel: l10n.playbackSpeed,
      ),
    );
  }

  Widget _buildBackgroundSoundWidget() {
    return request.hasBackgroundSound
        ? BgSoundWidget(
            isBackgroundSoundSelected: isBackgroundSoundSelected,
          )
        : const Icon(
            Icons.music_off,
            color: ColorConstants.white,
          );
  }

  void _showBackgroundSoundDisabledMessage(BuildContext context) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.backgroundSoundsDisabled),
      ),
    );
  }
}
