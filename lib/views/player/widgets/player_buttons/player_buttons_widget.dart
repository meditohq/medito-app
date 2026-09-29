import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/widgets/medito_icon.dart';

import '../../../../models/player/repeat_mode.dart' as medito_repeat;
import '../../../../providers/player/repeat_state_provider.dart';
import 'play_pause_button_widget.dart';
import 'repeat_mode_sheet.dart';

class PlayerButtonsWidget extends ConsumerWidget {
  const PlayerButtonsWidget({
    required this.onSkip10SecondsBackward,
    required this.onSkip10SecondsForward,
    required this.isPlaying,
    super.key,
    required this.onPlayPause,
    this.isPortrait = true,
    this.isLoading = false,
  });

  final Function() onSkip10SecondsBackward;
  final Function() onSkip10SecondsForward;
  final bool isPlaying;
  final Function() onPlayPause;
  final bool isPortrait;
  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repeatMode = ref.watch(repeatStateProvider);
    final l10n = AppLocalizations.of(context)!;

    if (isPortrait) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlayPauseButtonWidget(
            isPlaying: isPlaying,
            onPlayPause: onPlayPause,
            isLoading: isLoading,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _rewindButton(l10n),
              const SizedBox(width: 32),
              _repeatButton(context, repeatMode, l10n),
              const SizedBox(width: 32),
              _forwardButton(l10n),
            ],
          ),
        ],
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _rewindButton(l10n),
          const SizedBox(width: 32),
          PlayPauseButtonWidget(
            isPlaying: isPlaying,
            onPlayPause: onPlayPause,
            isLoading: isLoading,
          ),
          const SizedBox(width: 32),
          _forwardButton(l10n),
          const SizedBox(width: 32),
          _repeatButton(context, repeatMode, l10n),
        ],
      );
    }
  }

  IconButton _rewindButton(AppLocalizations l10n) {
    return IconButton(
      onPressed: onSkip10SecondsBackward,
      tooltip: l10n.skipBackward10Seconds,
      icon: const MeditoIcon(
        assetName: MeditoIcons.backward15,
        size: 40,
        color: Colors.white,
      ),
    );
  }

  IconButton _forwardButton(AppLocalizations l10n) {
    return IconButton(
      onPressed: onSkip10SecondsForward,
      tooltip: l10n.skipForward10Seconds,
      icon: const MeditoIcon(
        assetName: MeditoIcons.forward15,
        size: 40,
        color: Colors.white,
      ),
    );
  }

  Widget _repeatButton(
    BuildContext context,
    medito_repeat.RepeatMode repeatMode,
    AppLocalizations l10n,
  ) {
    return _RepeatButton(l10n: l10n);
  }
}

class _RepeatButton extends ConsumerWidget {
  const _RepeatButton({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repeatMode = ref.watch(repeatStateProvider);
    final (iconAsset, tooltip) = switch (repeatMode) {
      medito_repeat.RepeatMode.none => (MeditoIcons.repeat, l10n.repeat),
      medito_repeat.RepeatMode.once => (
        MeditoIcons.repeatOnce,
        l10n.repeatModeOnce,
      ),
      medito_repeat.RepeatMode.infinite => (
        MeditoIcons.repeat,
        l10n.repeatModeForever,
      ),
    };

    // Always full white: the icon opens a sheet, so dimming it for "off"
    // read as disabled. An active mode gets the same rounded highlight as the
    // speed and download buttons in the action bar.
    return IconButton(
      onPressed: () => showRepeatModeSheet(context),
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: repeatMode == medito_repeat.RepeatMode.none
            ? Colors.transparent
            : ColorConstants.graphite.withAlpha(200),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      icon: MeditoIcon(assetName: iconAsset, size: 32, color: Colors.white),
    );
  }
}
