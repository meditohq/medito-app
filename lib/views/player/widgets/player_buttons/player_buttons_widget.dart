import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/widgets/medito_icon.dart';

import '../../../../models/player/repeat_mode.dart' as medito_repeat;
import '../../../../providers/player/repeat_state_provider.dart';
import 'play_pause_button_widget.dart';

class PlayerButtonsWidget extends ConsumerWidget {
  const PlayerButtonsWidget({
    required this.onSkip10SecondsBackward,
    required this.onSkip10SecondsForward,
    required this.isPlaying,
    super.key,
    required this.onPlayPause,
    required this.onRepeat,
    this.isPortrait = true,
  });

  final Function() onSkip10SecondsBackward;
  final Function() onSkip10SecondsForward;
  final bool isPlaying;
  final Function() onPlayPause;
  final Function() onRepeat;
  final bool isPortrait;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repeatMode = ref.watch(repeatStateProvider);
    final l10n = AppLocalizations.of(context)!;

    if (isPortrait) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlayPauseButtonWidget(isPlaying: isPlaying, onPlayPause: onPlayPause),
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
          PlayPauseButtonWidget(isPlaying: isPlaying, onPlayPause: onPlayPause),
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
    return _RepeatButtonWithLabel(
      repeatMode: repeatMode,
      onRepeat: onRepeat,
      l10n: l10n,
    );
  }
}

class _RepeatButtonWithLabel extends ConsumerStatefulWidget {
  const _RepeatButtonWithLabel({
    required this.repeatMode,
    required this.onRepeat,
    required this.l10n,
  });

  final medito_repeat.RepeatMode repeatMode;
  final VoidCallback onRepeat;
  final AppLocalizations l10n;

  @override
  ConsumerState<_RepeatButtonWithLabel> createState() =>
      _RepeatButtonWithLabelState();
}

class _RepeatButtonWithLabelState
    extends ConsumerState<_RepeatButtonWithLabel> {
  Timer? _timer;
  bool _showLabel = false;
  String _currentLabel = '';

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    final l10n = widget.l10n;

    final nextMode = switch (widget.repeatMode) {
      medito_repeat.RepeatMode.none => medito_repeat.RepeatMode.once,
      medito_repeat.RepeatMode.once => medito_repeat.RepeatMode.infinite,
      medito_repeat.RepeatMode.infinite => medito_repeat.RepeatMode.none,
    };

    String labelText;
    switch (nextMode) {
      case medito_repeat.RepeatMode.none:
        labelText = l10n.repeatModeNormal;
        break;
      case medito_repeat.RepeatMode.once:
        labelText = l10n.repeatModeOnce;
        break;
      case medito_repeat.RepeatMode.infinite:
        labelText = l10n.repeatModeForever;
        break;
    }

    widget.onRepeat();

    _timer?.cancel();
    setState(() {
      _currentLabel = labelText;
      _showLabel = true;
    });

    _timer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _showLabel = false;
        });
      }
    });
  }

  String _tooltipForMode(medito_repeat.RepeatMode mode) {
    return switch (mode) {
      medito_repeat.RepeatMode.none => widget.l10n.repeat,
      medito_repeat.RepeatMode.once => widget.l10n.repeatModeOnce,
      medito_repeat.RepeatMode.infinite => widget.l10n.repeatModeForever,
    };
  }

  @override
  Widget build(BuildContext context) {
    final repeatMode = ref.watch(repeatStateProvider);
    var iconAsset = MeditoIcons.repeat;
    Color? iconColor;

    switch (repeatMode) {
      case medito_repeat.RepeatMode.none:
        iconColor = Colors.white.withValues(alpha: 0.5);
        break;
      case medito_repeat.RepeatMode.once:
        iconAsset = MeditoIcons.repeatOnce;
        iconColor = Colors.white;
        break;
      case medito_repeat.RepeatMode.infinite:
        iconColor = Colors.white;
        break;
    }

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: _handleTap,
          tooltip: _tooltipForMode(repeatMode),
          icon: MeditoIcon(assetName: iconAsset, size: 32, color: iconColor),
        ),
        if (_showLabel)
          Positioned(
            bottom: -40,
            child: AnimatedOpacity(
              opacity: _showLabel ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacityValue(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _currentLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
