import 'package:Medito/components/components.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/view_model/background_sounds/background_sounds_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BackgroundSoundView extends ConsumerWidget {
  const BackgroundSoundView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var backgroundSounds = ref.watch(backgroundSoundsProvider);
    return Scaffold(
      body: backgroundSounds.when(
        skipLoadingOnRefresh: false,
        data: (data) => _mainContent(context, data, ref),
        error: (err, stack) => ErrorComponent(
          message: err.toString(),
          onTap: () async => await ref.refresh(backgroundSoundsProvider),
        ),
        loading: () => BackgroundSoundsShimmerComponent(),
      ),
    );
  }

  CollapsibleHeaderComponent _mainContent(
      BuildContext context, List<BackgroundSoundsModel> data, WidgetRef ref) {
    return CollapsibleHeaderComponent(
      title: StringConstants.BACKGROUND_SOUNDS,
      leadingIconBgColor: ColorConstants.walterWhite,
      leadingIconColor: ColorConstants.almostBlack,
      headerHeight: 130,
      children: [
        _volumeSlider(),
        for (int i = 0; i < data.length; i++)
          _buildSoundsListTile(context, data[i])
      ],
    );
  }

  SliderTheme _volumeSlider() {
    return SliderTheme(
      data: SliderThemeData(
          // trackShape: CustomTrackShape(addTopPadding: false),
          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10.0),
          trackHeight: 72),
      child: Slider(
        value: 15,
        min: 0,
        max: 100,
        divisions: 10,
        activeColor: ColorConstants.purple,
        inactiveColor: ColorConstants.greyIsTheNewGrey,
        label: 'Set volume value',
        onChanged: (double newValue) {},
        semanticFormatterCallback: (double newValue) {
          return '${newValue.round()} dollars';
        },
      ),
    );
  }

  Container _buildSoundsListTile(
      BuildContext context, BackgroundSoundsModel sounds) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(width: 0.9, color: ColorConstants.softGrey),
        ),
      ),
      constraints: BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            sounds.name,
            style: Theme.of(context).primaryTextTheme.bodyLarge?.copyWith(
                  color: ColorConstants.walterWhite,
                  fontFamily: DmSans,
                  fontSize: 16,
                ),
          ),
        ],
      ),
    );
  }
}
