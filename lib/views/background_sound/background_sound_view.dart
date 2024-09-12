import 'package:medito/constants/constants.dart';
import 'package:medito/models/models.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/background_sounds/background_sounds_notifier.dart';
import '../../widgets/headers/medito_app_bar_small.dart';
import 'widgets/sound_listtile_widget.dart';
import 'widgets/volume_slider_widget.dart';

class BackgroundSoundView extends ConsumerStatefulWidget {
  const BackgroundSoundView({Key? key}) : super(key: key);

  @override
  ConsumerState<BackgroundSoundView> createState() =>
      _BackgroundSoundViewState();
}

class _BackgroundSoundViewState extends ConsumerState<BackgroundSoundView> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    super.dispose();
  }

  void _scrollListener() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    var backgroundSounds = ref.watch(backgroundSoundsProvider);

    return Scaffold(
      appBar: const MeditoAppBarSmall(
        title: StringConstants.backgroundSounds,
      ),
      bottomNavigationBar: SingleBackButtonActionBar(
        onBackPressed: () => Navigator.pop(context),
      ),
      body: backgroundSounds.when(
        skipLoadingOnRefresh: false,
        data: (data) => _mainContent(data),
        error: (err, stack) {
          return MeditoErrorWidget(
            message: err.toString(),
            onTap: () => ref.refresh(backgroundSoundsProvider),
          );
        },
        loading: () => const BackgroundSoundsShimmerWidget(),
      ),
    );
  }

  RefreshIndicator _mainContent(List<BackgroundSoundsModel> data) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(backgroundSoundsProvider);
        ref.read(backgroundSoundsProvider);
      },
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 80.0),
        children: [
          const VolumeSliderWidget(),
          Column(
            children: data
                .map((e) => SoundListTileWidget(
                      sound: e,
                    ))
                .toList(),
          ),
          height32,
        ],
      ),
    );
  }
}
