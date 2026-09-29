import 'package:flutter/material.dart';
import 'package:medito/constants/constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/player/audio_state_provider.dart';

/// Playback speeds offered in the player. Meditation audio is only ever
/// slowed down, so the range stops at normal speed.
const playbackSpeedOptions = [0.6, 0.7, 0.8, 0.9, 1.0];

String formatSpeed(double speed) => '${speed.toStringAsFixed(1)}×';

Future<void> showSpeedSheet(
  BuildContext context, {
  required ValueChanged<double> onSpeedChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
    builder: (_) => Consumer(
      builder: (context, ref, _) => SpeedSheet(
        initialSpeed: ref.read(audioStateProvider).speed.speed,
        onSpeedChanged: onSpeedChanged,
      ),
    ),
  );
}

/// Bottom sheet with a stepped slider for playback speed. Replaces the old
/// tap-to-cycle chip, where reaching a slower speed and getting back to 1.0×
/// meant cycling through every step. Each committed change (drag end, label
/// tap, reset) is applied immediately; the sheet stays open to fine-tune.
class SpeedSheet extends StatefulWidget {
  const SpeedSheet({
    super.key,
    required this.initialSpeed,
    required this.onSpeedChanged,
  });

  final double initialSpeed;
  final ValueChanged<double> onSpeedChanged;

  @override
  State<SpeedSheet> createState() => _SpeedSheetState();
}

class _SpeedSheetState extends State<SpeedSheet> {
  late int _index = _nearestIndex(widget.initialSpeed);

  /// Last speed sent to the player, so a drag that ends where it started
  /// doesn't re-apply (and re-log) the same speed.
  late double _applied = widget.initialSpeed;

  double get _speed => playbackSpeedOptions[_index];

  static int _nearestIndex(double speed) {
    var best = playbackSpeedOptions.length - 1;
    for (var i = 0; i < playbackSpeedOptions.length; i++) {
      if ((playbackSpeedOptions[i] - speed).abs() <
          (playbackSpeedOptions[best] - speed).abs()) {
        best = i;
      }
    }
    return best;
  }

  void _commit(int index) {
    setState(() => _index = index);
    final speed = playbackSpeedOptions[index];
    if (speed == _applied) return;
    _applied = speed;
    widget.onSpeedChanged(speed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final isNormal = _speed == 1.0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.playbackSpeed,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Keeps its space when hidden so the title row never jumps.
                Visibility(
                  visible: !isNormal,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: TextButton(
                    onPressed: () => _commit(playbackSpeedOptions.length - 1),
                    child: Text(
                      l10n.speedReset,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                formatSpeed(_speed),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontFamily: googleSans,
                  fontSize: 40,
                  fontWeight: FontWeight.w400,
                  color: onSurface,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                activeTrackColor: context.brandPurple,
                inactiveTrackColor: onSurface.withValues(alpha: 0.15),
                thumbColor: context.brandPurple,
                activeTickMarkColor: context.onBrandPurple.withValues(
                  alpha: 0.6,
                ),
                inactiveTickMarkColor: onSurface.withValues(alpha: 0.3),
                overlayColor: context.brandPurple.withValues(alpha: 0.12),
                showValueIndicator: ShowValueIndicator.never,
              ),
              child: Slider(
                value: _index.toDouble(),
                min: 0,
                max: (playbackSpeedOptions.length - 1).toDouble(),
                divisions: playbackSpeedOptions.length - 1,
                semanticFormatterCallback: (v) =>
                    formatSpeed(playbackSpeedOptions[v.round()]),
                onChanged: (v) => setState(() => _index = v.round()),
                onChangeEnd: (v) => _commit(v.round()),
              ),
            ),
            // Tappable stop labels, aligned under the slider's divisions
            // (the slider insets its track by the thumb/overlay radius).
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < playbackSpeedOptions.length; i++)
                    InkWell(
                      onTap: () => _commit(i),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: Text(
                          formatSpeed(playbackSpeedOptions[i]),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontSize: 14,
                            fontWeight: i == _index
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: onSurface.withValues(
                              alpha: i == _index ? 1 : 0.6,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
