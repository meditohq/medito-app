import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/scaffold_messenger_key.dart';
import 'package:medito/models/models.dart';
import 'package:medito/views/player/widgets/bottom_actions/widgets/audio_download_widget.dart';
import 'package:medito/views/player/widgets/bottom_actions/widgets/audio_speed_widget.dart';
import 'package:medito/views/player/widgets/bottom_actions/widgets/bg_sound_widget.dart';
import 'package:medito/views/player/widgets/bottom_actions/widgets/speed_sheet.dart';

import 'package:medito/views/background_sound/background_sound_view.dart';

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
        child: const Icon(Icons.close, color: ColorConstants.white),
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
            ? () {
                FirebaseAnalyticsService().logEvent(
                  name: AnalyticsEventConstants.playerBackgroundSoundsOpened,
                );
                showBackgroundSoundSheet(context);
              }
            : () => _showBackgroundSoundDisabledMessage(context),
        semanticLabel: l10n.backgroundSounds,
      ),
      rightItem: BottomActionBarItem(
        child: const AudioSpeedWidget(),
        onTap: () => showSpeedSheet(
          context,
          onSpeedChanged: (speed) {
            FirebaseAnalyticsService().logEvent(
              name: AnalyticsEventConstants.playerSpeedChanged,
              parameters: {'speed': speed, 'track_id': request.trackId},
            );
            onSpeedChanged(speed);
          },
        ),
        semanticLabel: l10n.playbackSpeed,
      ),
    );
  }

  Widget _buildBackgroundSoundWidget() {
    return request.hasBackgroundSound
        ? BgSoundWidget(isBackgroundSoundSelected: isBackgroundSoundSelected)
        : const Icon(Icons.music_off, color: ColorConstants.white);
  }

  void _showBackgroundSoundDisabledMessage(BuildContext context) {
    FirebaseAnalyticsService().logEvent(
      name: AnalyticsEventConstants.playerBackgroundSoundsUnavailable,
      parameters: {'track_id': request.trackId},
    );
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.backgroundSoundsDisabled),
      ),
    );
  }
}
