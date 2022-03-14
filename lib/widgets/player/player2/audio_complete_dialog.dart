import 'package:Medito/network/player/player_bloc.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/main/app_bar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../../../utils/colors.dart';

class AudioCompleteDialog extends StatefulWidget {
  final PlayerBloc bloc;

  const AudioCompleteDialog({Key key, this.bloc}) : super(key: key);

  @override
  _AudioCompleteDialogState createState() => _AudioCompleteDialogState();
}

class _AudioCompleteDialogState extends State<AudioCompleteDialog> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        color: MeditoColors.darkMoon,
        child: Column(
          children: [
            MeditoAppBarWidget(
                hasCloseButton: true,
                closePressed: _closePressed,
                transparent: true),
            _buildDonateCard(),
            Container(height: 16),
            _buildRatingCard(),
            Container(height: 16),
            _buildFollowUsCard(),
            Container(height: 16),
            _buildCloseButton()
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
      color: MeditoColors.deepNight,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset('assets/images/colourful_hearts.svg'),
            Container(height: 16),
            Text(
                'Medito is keeping access to meditation free, forever. Say thanks by donating.',
                style: TextStyle(color: Colors.white)),
            Container(height: 16),
            TextButton.icon(
                style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.0),
                    ),
                    backgroundColor: MeditoColors.darkMoon,
                    padding: const EdgeInsets.all(16.0)),
                onPressed: _onDonateTap,
                icon: Icon(Icons.favorite, color: MeditoColors.walterWhite),
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
      color: MeditoColors.easterYellow,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text('How do you feel after this session?',
                style: TextStyle(color: Colors.black)),
            Container(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MaterialButton(
                  height: 48,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minWidth: 68,
                  color: MeditoColors.darkMoon,
                  onPressed: _sadPressed,
                  child: SvgPicture.asset(
                    'assets/images/ic_sad_face.svg',
                  ),
                ),
                Container(width: 12),
                MaterialButton(
                  height: 48,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minWidth: 68,
                  color: MeditoColors.darkMoon,
                  onPressed: _neutralFacePressed,
                  child: SvgPicture.asset(
                    'assets/images/ic_neutral_face.svg',
                  ),
                ),
                Container(width: 12),
                MaterialButton(
                  height: 48,
                  minWidth: 68,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: MeditoColors.darkMoon,
                  onPressed: _happyFacePressed,
                  child: SvgPicture.asset(
                    'assets/images/ic_happy_face.svg',
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Card _buildFollowUsCard() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      color: MeditoColors.deepNight,
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
                        backgroundColor: MeditoColors.darkMoon,
                        padding: const EdgeInsets.all(16.0)),
                    onPressed: _onTwitterTap,
                    icon: SvgPicture.asset(
                      'assets/images/ic_twitter.svg',
                    ),
                    label:
                        Text('Twitter', style: TextStyle(color: Colors.white))),
                Container(width: 12),
                TextButton.icon(
                    style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.0),
                        ),
                        backgroundColor: MeditoColors.darkMoon,
                        padding: const EdgeInsets.all(16.0)),
                    onPressed: _onYoutubeTap,
                    icon: SvgPicture.asset(
                      'assets/images/ic_youtube.svg',
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
                        backgroundColor: MeditoColors.darkMoon,
                        padding: const EdgeInsets.all(16.0)),
                    onPressed: _onInstaTap,
                    icon: SvgPicture.asset(
                      'assets/images/ic_insta.svg',
                    ),
                    label: Text('Instagram',
                        style: TextStyle(color: Colors.white))),
                Container(width: 12),
                TextButton.icon(
                    style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.0),
                        ),
                        backgroundColor: MeditoColors.darkMoon,
                        padding: const EdgeInsets.all(16.0)),
                    onPressed: _onRedditTap,
                    icon: SvgPicture.asset(
                      'assets/images/ic_reddit.svg',
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
    // context.pop();
  }

  Widget _buildCloseButton() {
    return TextButton(
        onPressed: _closePressed,
        child: Text('Close', style: TextStyle(color: Colors.white)));
  }

  void _onDonateTap() {
    launchUrl('https://meditofoundation.org/donate');
  }

  void _sadPressed() {}

  void _neutralFacePressed() {}

  void _happyFacePressed() {}

  void _onTwitterTap() {
    launchUrl('https://twitter.com/meditohq');
  }

  void _onYoutubeTap() {
    launchUrl('https://www.youtube.com/c/Medito');
  }

  void _onInstaTap() {
    launchUrl('https://www.instagram.com/meditohq/');
  }

  void _onRedditTap() {
    launchUrl('https://www.reddit.com/r/medito/');
  }
}
