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
    var textColor = _label != StringConstants.x1
        ? ColorConstants.lightPurple
        : ColorConstants.walterWhite;
    ColorConstants.walterWhite;

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
      child: Text(
        _label,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: textColor, fontFamily: DmMono, fontSize: 18),
        textAlign: TextAlign.center,
      ),
    );
  }
}

extension on String {
  double get toDouble => double.parse(substring(1));
}
