import 'package:Medito/components/components.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/utils.dart';
import 'package:flutter/material.dart';
import 'components/artist_title_component.dart';
import 'components/bottom_action_component.dart';
import 'components/duration_indicatior_component.dart';
import 'components/player_buttons_component.dart';

class PlayerView extends StatefulWidget {
  const PlayerView({super.key, required this.sessionModel});
  final SessionModel sessionModel;
  @override
  State<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<PlayerView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: false,
      extendBodyBehindAppBar: true,
      body: Container(
        child: Stack(
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
                  PlayerButtonsComponent(),
                  height16,
                  DurationIndicatorComponent(),
                  height16,
                  BottomActionComponent(),
                  height16,
                ],
              ),
            ),
          ],
        ),
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
