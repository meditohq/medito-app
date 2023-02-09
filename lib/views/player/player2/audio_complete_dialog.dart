import 'package:Medito/network/player/player_bloc.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/views/main/app_bar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:Medito/constants/constants.dart';

class AudioCompleteDialog extends StatefulWidget {
  final PlayerBloc? bloc;

  final mediaItem;

  const AudioCompleteDialog({Key? key, this.bloc, this.mediaItem})
      : super(key: key);

  @override
  _AudioCompleteDialogState createState() => _AudioCompleteDialogState();
}

class _AudioCompleteDialogState extends State<AudioCompleteDialog> {
  var rated = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        color: ColorConstants.darkMoon,
        child: Column(
          children: [
            MeditoAppBarWidget(
                hasCloseButton: true,
                closePressed: _closePressed,
                isTransparent: true),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  _buildDonateCard(),
                  Container(height: 16),
                  _buildRatingCard(),
                  Container(height: 16),
                  _buildFollowUsCard(),
                  Container(height: 16),
                  _buildCloseButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Card _buildDonateCard() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      color: ColorConstants.deepNight,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(AssetConstants.icColourfulHearts),
            Container(height: 16),
            Text(
                'Medito is keeping access to meditation free, forever. Say thanks by donating.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white)),
            Container(height: 16),
            TextButton.icon(
                style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.0),
                    ),
                    backgroundColor: ColorConstants.darkMoon,
                    padding: const EdgeInsets.all(16.0)),
                onPressed: _onDonateTap,
                icon: Icon(Icons.favorite, color: ColorConstants.walterWhite),
                label:
                    Text('Donate now', style: TextStyle(color: Colors.white)))
          ],
        ),
      ),
    );
  }

  Card _buildRatingCard() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      color: ColorConstants.easterYellow,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: AnimatedCrossFade(
          firstChild: _notRatedContent(),
          secondChild: _ratedContent(),
          duration: Duration(milliseconds: 250),
          crossFadeState:
              rated ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        ),
      ),
    );
  }

  Widget _ratedContent() {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Thanks for your feedback!', style: TextStyle(color: Colors.black)),
      ],
    );
  }

  Column _notRatedContent() {
    return Column(
      children: [
        Text('How do you feel after this session?',
            style: TextStyle(color: Colors.black)),
        Container(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MaterialButton(
              height: 48,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minWidth: 68,
              color: ColorConstants.darkMoon,
              onPressed: _sadPressed,
              child: SvgPicture.asset(
                AssetConstants.icSadFace,
              ),
            ),
            Container(width: 12),
            MaterialButton(
              height: 48,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minWidth: 68,
              color: ColorConstants.darkMoon,
              onPressed: _neutralFacePressed,
              child: SvgPicture.asset(
                AssetConstants.icNeutralFace,
              ),
            ),
            Container(width: 12),
            MaterialButton(
              elevation: 0,
              height: 48,
              minWidth: 68,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: ColorConstants.darkMoon,
              onPressed: _happyFacePressed,
              child: SvgPicture.asset(
                AssetConstants.icHappyFace,
              ),
            ),
          ],
        )
      ],
    );
  }

  Card _buildFollowUsCard() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      color: ColorConstants.deepNight,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Follow us for our latest updates.',
                style: TextStyle(color: Colors.white)),
            Container(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                    style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.0),
                        ),
                        backgroundColor: ColorConstants.darkMoon,
                        padding: const EdgeInsets.all(16.0)),
                    onPressed: _onTwitterTap,
                    icon: SvgPicture.asset(
                     AssetConstants.icTwitter,
                    ),
                    label:
                        Text('Twitter', style: TextStyle(color: Colors.white))),
                Container(width: 12),
                TextButton.icon(
                    style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.0),
                        ),
                        backgroundColor: ColorConstants.darkMoon,
                        padding: const EdgeInsets.all(16.0)),
                    onPressed: _onYoutubeTap,
                    icon: SvgPicture.asset(
                      AssetConstants.icYoutube,
                    ),
                    label:
                        Text('Youtube', style: TextStyle(color: Colors.white))),
              ],
            ),
            Container(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                    style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.0),
                        ),
                        backgroundColor: ColorConstants.darkMoon,
                        padding: const EdgeInsets.all(16.0)),
                    onPressed: _onInstaTap,
                    icon: SvgPicture.asset(
                    AssetConstants.icInsta,
                    ),
                    label: Text('Instagram',
                        style: TextStyle(color: Colors.white))),
                Container(width: 12),
                TextButton.icon(
                    style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.0),
                        ),
                        backgroundColor: ColorConstants.darkMoon,
                        padding: const EdgeInsets.all(16.0)),
                    onPressed: _onRedditTap,
                    icon: SvgPicture.asset(
                      AssetConstants.icReddit,
                    ),
                    label:
                        Text('Reddit', style: TextStyle(color: Colors.white))),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _closePressed() {
    GoRouter.of(context).pop();
  }

  Widget _buildCloseButton() {
    return Row(
      children: [
        Expanded(
          child: TextButton(
              onPressed: _closePressed,
              child: Text('Close', style: TextStyle(color: Colors.white))),
        ),
      ],
    );
  }

  void _onDonateTap() {
    launchUrl('https://bit.ly/3vRoz8N');
  }

  void _sadPressed() {
    setState(() {
      rated = true;
    });
    widget.bloc?.postRating(1, widget.mediaItem);
  }

  void _neutralFacePressed() {
    setState(() {
      rated = true;
    });
    widget.bloc?.postRating(2, widget.mediaItem);
  }

  void _happyFacePressed() {
    setState(() {
      rated = true;
    });
    widget.bloc?.postRating(3, widget.mediaItem);
  }

  void _onTwitterTap() {
    launchUrl('https://bit.ly/3vRR4TS');
  }

  void _onYoutubeTap() {
    launchUrl('https://bit.ly/3IVUSHC');
  }

  void _onInstaTap() {
    launchUrl('https://bit.ly/3sST5xm');
  }

  void _onRedditTap() {
    launchUrl('https://bit.ly/3hOity1');
  }
}
