import 'package:Medito/components/components.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/view_model/audio_player/audio_player_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'components/artist_title_component.dart';
import 'components/bottom_actions/bottom_action_component.dart';
import 'components/duration_indicatior_component.dart';
import 'components/player_buttons_component.dart';

class PlayerView extends ConsumerStatefulWidget {
  const PlayerView({super.key, required this.sessionModel, required this.file});
  final SessionModel sessionModel;
  final SessionFilesModel file;
  @override
  ConsumerState<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends ConsumerState<PlayerView> {
  @override
  void initState() {
    ref.read(audioPlayerNotifierProvider).setSessionAudio(widget.file.path);
    super.initState();
  }

  @override
  void dispose() {
    // ref.read(audioPlayerNotifierProvider).disposeSessionAudio();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: false,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          _bgImage(context),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CloseButtonComponent(
                  onPressed: () => router.pop(),
                  bgColor: ColorConstants.walterWhite,
                  icColor: ColorConstants.almostBlack,
                ),
                Spacer(),
                ArtistTitleComponent(sessionModel: widget.sessionModel),
                Spacer(),
                PlayerButtonsComponent(file: widget.file),
                height16,
                DurationIndicatorComponent(file: widget.file),
                height16,
                BottomActionComponent(
                  sessionModel: widget.sessionModel,
                ),
                height16,
              ],
            ),
          ),
        ],
      ),
    );
  }

  SizedBox _bgImage(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height,
      child: ImageFiltered(
        imageFilter: ColorFilter.mode(
            ColorConstants.almostBlack.withOpacity(0.4), BlendMode.colorBurn),
        child: NetworkImageComponent(url: widget.sessionModel.coverUrl),
      ),
    );
  }
}
