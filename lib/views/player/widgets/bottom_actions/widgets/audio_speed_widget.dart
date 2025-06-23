import 'package:medito/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AudioSpeedWidget extends ConsumerStatefulWidget {
  const AudioSpeedWidget({super.key, required this.onSpeedChanged});

  final Function(double) onSpeedChanged;

  @override
  ConsumerState<AudioSpeedWidget> createState() => _AudioSpeedComponentState();
}

class _AudioSpeedComponentState extends ConsumerState<AudioSpeedWidget> {
  String _label = StringConstants.x1;

  @override
  Widget build(BuildContext context) {
    var isSelected = _label != StringConstants.x1;

    return GestureDetector(
      onTap: () {
        if (_label == StringConstants.x06) {
          _label = StringConstants.x07;
        } else if (_label == StringConstants.x07) {
          _label = StringConstants.x08;
        } else if (_label == StringConstants.x08) {
          _label = StringConstants.x09;
        } else if (_label == StringConstants.x09) {
          _label = StringConstants.x1;
        } else if (_label == StringConstants.x1) {
          _label = StringConstants.x06;
        }

        widget.onSpeedChanged(_label.toDouble);
      },
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
            _getFormattedLabel(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ColorConstants.white,
                  fontFamily: dmMono,
                  fontSize: 18,
                ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  String _getFormattedLabel() {
    if (_label == StringConstants.x06) {
      return '0.6×';
    } else if (_label == StringConstants.x07) {
      return '0.7×';
    } else if (_label == StringConstants.x08) {
      return '0.8×';
    } else if (_label == StringConstants.x09) {
      return '0.9×';
    } else if (_label == StringConstants.x1) {
      return '1.0×';
    } else {
      return _label;
    }
  }
}

extension on String {
  double get toDouble => double.parse(substring(1));
}
