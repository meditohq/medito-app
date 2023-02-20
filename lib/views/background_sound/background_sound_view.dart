import 'package:Medito/components/components.dart';
import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';

class BackgroundSoundView extends StatelessWidget {
  const BackgroundSoundView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: CollapsibleHeaderComponent(
        title: StringConstants.BACKGROUND_SOUNDS,
        leadingIconBgColor: ColorConstants.walterWhite,
        leadingIconColor: ColorConstants.almostBlack,
        headerHeight: 130,
        children: [
          
        ],
      ),
    );
  }
}
