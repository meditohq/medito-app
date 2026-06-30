import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AudioSpeedWidget extends ConsumerStatefulWidget {
  const AudioSpeedWidget({super.key, required this.onSpeedChanged});

  final Function(double) onSpeedChanged;

  @override
  ConsumerState<AudioSpeedWidget> createState() => _AudioSpeedComponentState();
}

class _AudioSpeedComponentState extends ConsumerState<AudioSpeedWidget> {
  static const List<double> _speedOptions = [0.6, 0.7, 0.8, 0.9, 1.0];
  int _currentIndex = 4; // Start at 1.0x

  double get _currentSpeed => _speedOptions[_currentIndex];

  @override
  Widget build(BuildContext context) {
    var isSelected = _currentSpeed != 1.0;
    final l10n = AppLocalizations.of(context)!;

    return Semantics(
      label: '${l10n.playbackSpeed}: ${_currentSpeed.toStringAsFixed(1)}×',
      button: true,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentIndex = (_currentIndex + 1) % _speedOptions.length;
          });
          widget.onSpeedChanged(_currentSpeed);
        },
        child: ExcludeSemantics(
          child: IntrinsicWidth(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              height: 48,
              alignment: Alignment.center,
              decoration: isSelected
                  ? BoxDecoration(
                      color: ColorConstants.graphite.withAlpha(200),
                      borderRadius: BorderRadius.circular(6),
                    )
                  : null,
              child: Text(
                '${_currentSpeed.toStringAsFixed(1)}×',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ColorConstants.white,
                  fontFamily: dmMono,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
