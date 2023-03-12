import 'package:Medito/constants/strings/asset_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class PlayerButtonsComponent extends StatelessWidget {
  const PlayerButtonsComponent({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _rewindButton(),
        SizedBox(width: 35),
        _playPauseButton(),
        SizedBox(width: 35),
        _forwardButton()
      ],
    );
  }

  InkWell _rewindButton() {
    return InkWell(
      onTap: () => {},
      child: SvgPicture.asset(
        AssetConstants.icReplay10,
      ),
    );
  }

  InkWell _forwardButton() {
    return InkWell(
      onTap: () => {},
      child: SvgPicture.asset(
        AssetConstants.icForward30,
      ),
    );
  }

  AnimatedCrossFade _playPauseButton() {
    return AnimatedCrossFade(
      firstChild: Icon(
        Icons.play_circle_fill,
        size: 80,
      ),
      secondChild: Icon(
        Icons.pause_circle_filled,
        size: 80,
      ),
      crossFadeState: CrossFadeState.showSecond,
      duration: Duration(milliseconds: 500),
    );
  }
}
