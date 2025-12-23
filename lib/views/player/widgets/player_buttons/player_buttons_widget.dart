import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/widgets/medito_huge_icon.dart';

import '../../../../providers/player/repeat_state_provider.dart';
import '../../../../src/audio_pigeon.g.dart';
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

    if (isPortrait) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlayPauseButtonWidget(
            isPlaying: isPlaying,
            onPlayPause: onPlayPause,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _rewindButton(),
              const SizedBox(width: 32),
              _repeatButton(context, repeatMode),
              const SizedBox(width: 32),
              _forwardButton(),
            ],
          ),
        ],
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _rewindButton(),
          const SizedBox(width: 32),
          PlayPauseButtonWidget(
            isPlaying: isPlaying,
            onPlayPause: onPlayPause,
          ),
          const SizedBox(width: 32),
          _forwardButton(),
          const SizedBox(width: 32),
          _repeatButton(context, repeatMode),
        ],
      );
    }
  }

  IconButton _rewindButton() {
    return IconButton(
      onPressed: onSkip10SecondsBackward,
      icon: const MeditoIcon(
        assetName: MeditoIcons.backward15,
        size: 40,
        color: Colors.white,
      ),
    );
  }

  IconButton _forwardButton() {
    return IconButton(
      onPressed: onSkip10SecondsForward,
      icon: const MeditoIcon(
        assetName: MeditoIcons.forward15,
        size: 40,
        color: Colors.white,
      ),
    );
  }

  Widget _repeatButton(BuildContext context, RepeatMode repeatMode) {
    return _RepeatButtonWithLabel(
      repeatMode: repeatMode,
      onRepeat: onRepeat,
    );
  }
}

class _RepeatButtonWithLabel extends ConsumerStatefulWidget {
  const _RepeatButtonWithLabel({
    required this.repeatMode,
    required this.onRepeat,
  });

  final RepeatMode repeatMode;
  final VoidCallback onRepeat;

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
    final localizations = AppLocalizations.of(context)!;

    final nextMode = switch (widget.repeatMode) {
      RepeatMode.none => RepeatMode.once,
      RepeatMode.once => RepeatMode.infinite,
      RepeatMode.infinite => RepeatMode.none,
    };

    String labelText;
    switch (nextMode) {
      case RepeatMode.none:
        labelText = localizations.repeatModeNormal;
        break;
      case RepeatMode.once:
        labelText = localizations.repeatModeOnce;
        break;
      case RepeatMode.infinite:
        labelText = localizations.repeatModeForever;
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

  @override
  Widget build(BuildContext context) {
    final repeatMode = ref.watch(repeatStateProvider);
    var iconAsset = MeditoIcons.repeat;
    Color? iconColor;

    switch (repeatMode) {
      case RepeatMode.none:
        iconColor = Colors.white.withValues(alpha: 0.5);
        break;
      case RepeatMode.once:
        iconAsset = MeditoIcons.repeatOnce;
        iconColor = Colors.white;
        break;
      case RepeatMode.infinite:
        iconColor = Colors.white;
        break;
    }

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: _handleTap,
          icon: MeditoIcon(
            assetName: iconAsset,
            size: 32,
            color: iconColor,
          ),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
