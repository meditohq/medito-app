import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'widgets/artist_title_widget.dart';
import 'widgets/background_image_widget.dart';
import 'widgets/bottom_actions/bottom_action_widget.dart';
import 'widgets/duration_indicator_widget.dart';
import 'widgets/overlay_cover_image_widget.dart';
import 'widgets/player_buttons/player_buttons_widget.dart';

class PlayerView extends ConsumerStatefulWidget {
  const PlayerView({
    super.key,
    required this.trackModel,
    required this.file,
  });
  final TrackModel trackModel;
  final TrackFilesModel file;
  @override
  ConsumerState<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends ConsumerState<PlayerView>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    var coverUrl = widget.trackModel.coverUrl;
    var artist = widget.trackModel.artist;

    return BackButtonListener(
      onBackButtonPressed: () async => await _onWillPop(context),
      child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            BackgroundImageWidget(imageUrl: coverUrl),
            SafeArea(
              child: Column(
                children: [
                  height16,
                  HandleBarWidget(),
                  Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 4.0,
                    ),
                    child: ArtistTitleWidget(
                      trackTitle: widget.trackModel.title,
                      artistName: artist?.name,
                      artistUrlPath: artist?.path,
                      isPlayerScreen: true,
                    ),
                  ),
                  OverlayCoverImageWidget(imageUrl: coverUrl),
                  DurationIndicatorWidget(
                    file: widget.file,
                    trackId: widget.trackModel.id,
                  ),
                  Spacer(),
                  PlayerButtonsWidget(
                    file: widget.file,
                    trackModel: widget.trackModel,
                  ),
                  Spacer(
                    flex: 2,
                  ),
                  BottomActionWidget(
                    trackModel: widget.trackModel,
                    file: widget.file,
                  ),
                  height16,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _onWillPop(BuildContext context) async {
    var currentPage = ref.read(pageviewNotifierProvider).currentPage;
    var currentLocation = GoRouter.of(context).location;
    if (currentLocation.contains(RouteConstants.backgroundSoundsPath)) {
      context.pop();

      return true;
    } else if (currentPage == 1) {
      ref.read(pageviewNotifierProvider).gotoPreviousPage();

      return true;
    }

    return false;
  }

  @override
  bool get wantKeepAlive => true;
}
