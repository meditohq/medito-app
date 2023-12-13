import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/widgets/headers/medito_app_bar_small.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'widgets/artist_title_widget.dart';
import 'widgets/bottom_actions/bottom_action_widget.dart';
import 'widgets/duration_indicator_widget.dart';
import 'widgets/overlay_cover_image_widget.dart';
import 'widgets/player_buttons/player_buttons_widget.dart';

class PlayerView extends ConsumerStatefulWidget {
  const PlayerView({
    super.key,
  });

  @override
  ConsumerState<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends ConsumerState<PlayerView>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);

    var currentlyPlayingTrack = ref.watch(playerProvider);
    if (currentlyPlayingTrack == null) {
      return MeditoErrorWidget(
        onTap: () => context.pop(),
        message: StringConstants.unableToLoadAudio,
      );
    }

    var coverUrl = currentlyPlayingTrack.coverUrl;
    var artist = currentlyPlayingTrack.artist;
    var file = currentlyPlayingTrack.audio.first.files.first;

    var size = MediaQuery.of(context).size.width;
    var spacerHeight48 = size <= 380.0 ? 10.0 : 56.0;
    var spacerHeight20 = size <= 380.0 ? 0.0 : 20.0;
    var spacerHeight24 = size <= 380.0 ? 0.0 : 24.0;

    return WillPopScope(
      onWillPop: _handleClose,
      child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        appBar: MeditoAppBarSmall(
          hasCloseButton: true,
          closePressed: () => _handleClose(),
          isTransparent: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: spacerHeight20),
                OverlayCoverImageWidget(imageUrl: coverUrl),
                SizedBox(height: spacerHeight48),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: ArtistTitleWidget(
                    trackTitle: currentlyPlayingTrack.title,
                    artistName: artist?.name,
                    artistUrlPath: artist?.path,
                    isPlayerScreen: true,
                  ),
                ),
                DurationIndicatorWidget(
                  file: file,
                  trackId: currentlyPlayingTrack.id,
                ),
                SizedBox(height: spacerHeight24),
                Transform.translate(
                  offset: Offset(0, -10),
                  child: PlayerButtonsWidget(
                    file: file,
                    trackModel: currentlyPlayingTrack,
                  ),
                ),
                SizedBox(height: spacerHeight24),
                BottomActionWidget(
                  trackModel: currentlyPlayingTrack,
                  file: file,
                ),
                SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _handleClose() async {
    final audioProvider = ref.read(audioPlayerNotifierProvider);
    await audioProvider.stop();

    context.pop();

    return true;
  }

  @override
  bool get wantKeepAlive => true;
}
