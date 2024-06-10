import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/background_sounds/background_sounds_notifier.dart';
import 'widgets/sound_listtile_widget.dart';
import 'widgets/volume_slider_widget.dart';

class BackgroundSoundView extends ConsumerStatefulWidget {
  const BackgroundSoundView({Key? key}) : super(key: key);

  @override
  ConsumerState<BackgroundSoundView> createState() =>
      _BackgroundSoundViewState();
}

class _BackgroundSoundViewState extends ConsumerState<BackgroundSoundView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    setState(() => {});
  }

  @override
  Widget build(BuildContext context) {
    var connectivityStatus = ref.watch(connectivityStatusProvider);

    ref.listen(connectivityStatusProvider, (prev, next) {
      if (next == ConnectivityStatus.isDisconnected) {
        showSnackBar(context, StringConstants.connectivityError);
      }
    });
    var localBackgroundSounds =
        ref.watch(fetchLocallySavedBackgroundSoundsProvider);
    var backgroundSounds = ref.watch(backgroundSoundsProvider);

    if (connectivityStatus == ConnectivityStatus.isDisconnected) {
      return Scaffold(
        body: localBackgroundSounds.when(
          skipLoadingOnRefresh: true,
          skipLoadingOnReload: true,
          data: (data) {
            if (data != null) {
              return _mainContent(
                connectivityStatus,
                data,
              );
            }

            return MeditoErrorWidget(
              message: StringConstants.noBgSoundAvailable,
              onTap: () => ref.refresh(backgroundSoundsProvider),
            );
          },
          error: (err, stack) {
            return MeditoErrorWidget(
              message: err.toString(),
              onTap: () =>
                  ref.refresh(fetchLocallySavedBackgroundSoundsProvider),
            );
          },
          loading: () => BackgroundSoundsShimmerWidget(),
        ),
      );
    }

    return Scaffold(
      body: backgroundSounds.when(
        skipLoadingOnRefresh: false,
        data: (data) => _mainContent(
          connectivityStatus,
          data,
        ),
        error: (err, stack) {
          return MeditoErrorWidget(
            message: err.toString(),
            onTap: () => ref.refresh(backgroundSoundsProvider),
          );
        },
        loading: () => BackgroundSoundsShimmerWidget(),
      ),
    );
  }

  RefreshIndicator _mainContent(
    ConnectivityStatus status,
    List<BackgroundSoundsModel> data,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        if (status == ConnectivityStatus.isDisconnected) {
          return;
        } else {
          ref.invalidate(backgroundSoundsProvider);
          ref.read(backgroundSoundsProvider);
        }
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          MeditoAppBarLarge(
            scrollController: _scrollController,
            title: StringConstants.backgroundSounds,
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              VolumeSliderWidget(),
              Column(
                children: data
                    .map((e) => SoundListTileWidget(
                          sound: e,
                        ))
                    .toList(),
              ),
              height32,
            ]),
          ),
        ],
      ),
    );
  }
}
