import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/scaffold_messenger_key.dart';
import 'package:medito/models/models.dart';
import 'package:medito/models/timer/timer_session.dart';
import 'package:medito/views/player/widgets/bottom_actions/widgets/audio_download_widget.dart';
import 'package:medito/views/player/widgets/bottom_actions/widgets/audio_speed_widget.dart';
import 'package:medito/views/player/widgets/bottom_actions/widgets/background_sound_button.dart';
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

    // A timer is local silence: nothing to download, and speed would only
    // change how long the session takes. Keep close and the sound picker.
    if (request.isTimer) {
      return BottomActionBar(
        leftItem: BottomActionBarItem(
          child: const Icon(Icons.close, color: ColorConstants.white),
          onTap: onClosePressed,
          semanticLabel: l10n.close,
        ),
        rightItem: _backgroundSoundItem(context),
      );
    }

    return BottomActionBar(
      layout: BottomActionBarLayout.edgeAligned,
      leftItem: BottomActionBarItem(
        child: const Icon(Icons.close, color: ColorConstants.white),
        onTap: onClosePressed,
        semanticLabel: l10n.close,
      ),
      leftCenterItem: BottomActionBarItem.custom(
        child: AudioDownloadWidget(request: request),
      ),
      rightCenterItem: _backgroundSoundItem(context),
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
        // No tooltip: AudioSpeedWidget names itself ("Playback speed, 1.0
        // times"), and the visible "1.0×" was all screen readers got.
      ),
    );
  }

  BottomActionBarItem _backgroundSoundItem(BuildContext context) {
    if (!request.hasBackgroundSound) {
      return BottomActionBarItem(
        child: const Icon(Icons.music_off, color: ColorConstants.white),
        onTap: () => _showBackgroundSoundDisabledMessage(context),
        // Says why it's crossed out, as the snackbar it opens does.
        semanticLabel: AppLocalizations.of(context)!.backgroundSoundsDisabled,
      );
    }
    return BottomActionBarItem.custom(
      child: BackgroundSoundButton(
        isBackgroundSoundSelected: isBackgroundSoundSelected,
        onPressed: () {
          FirebaseAnalyticsService().logEvent(
            name: AnalyticsEventConstants.playerBackgroundSoundsOpened,
          );
          showBackgroundSoundSheet(context);
        },
      ),
    );
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
