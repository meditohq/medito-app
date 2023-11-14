import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
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

    return WillPopScope(
      onWillPop: () async {
        return false;
      },
      child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        backgroundColor: ColorConstants.ebony,
        body: SafeArea(
          child: Column(
            children: [
              height20,
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: defaultPadding,
                  ),
                  child: CloseButtonWidget(
                    icColor: ColorConstants.walterWhite,
                    onPressed: _handleClose,
                    isShowCircle: false,
                  ),
                ),
              ),
              height20,
              OverlayCoverImageWidget(imageUrl: coverUrl),
              height20,
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                ),
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
              Spacer(),
              Transform.translate(
                offset: Offset(0, -20),
                child: PlayerButtonsWidget(
                  file: file,
                  trackModel: currentlyPlayingTrack,
                ),
              ),
              Spacer(),
              BottomActionWidget(
                trackModel: currentlyPlayingTrack,
                file: file,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleClose() {
    final audioProvider = ref.read(audioPlayerNotifierProvider);
    audioProvider.stop();

    context.pop();
  }

  @override
  bool get wantKeepAlive => true;
}
