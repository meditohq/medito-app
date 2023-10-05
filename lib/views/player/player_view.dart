import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/artist_title_widget.dart';
import 'widgets/background_image_widget.dart';
import 'widgets/bottom_actions/bottom_action_widget.dart';
import 'widgets/duration_indicator_widget.dart';
import 'widgets/overlay_cover_image_widget.dart';
import 'widgets/player_buttons/player_buttons_widget.dart';

class PlayerView extends ConsumerStatefulWidget {
  const PlayerView({
    super.key,
    required this.meditationModel,
    required this.file,
  });
  final MeditationModel meditationModel;
  final MeditationFilesModel file;
  @override
  ConsumerState<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends ConsumerState<PlayerView>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    var coverUrl = widget.meditationModel.coverUrl;
    var artist = widget.meditationModel.artist;

    return BackButtonListener(
      onBackButtonPressed: _onWillPop,
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
                      meditationTitle: widget.meditationModel.title,
                      artistName: artist?.name,
                      artistUrlPath: artist?.path,
                      isPlayerScreen: true,
                    ),
                  ),
                  OverlayCoverImageWidget(imageUrl: coverUrl),
                  DurationIndicatorWidget(
                    file: widget.file,
                    meditationId: widget.meditationModel.id,
                  ),
                  Spacer(),
                  PlayerButtonsWidget(
                    file: widget.file,
                    meditationModel: widget.meditationModel,
                  ),
                  Spacer(
                    flex: 2,
                  ),
                  BottomActionWidget(
                    meditationModel: widget.meditationModel,
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

  Future<bool> _onWillPop() async {
    if (ref.read(pageviewNotifierProvider).currentPage == 1) {
      ref.read(pageviewNotifierProvider).gotoPreviousPage();

      return true;
    }

    return false;
  }

  @override
  bool get wantKeepAlive => true;
}
