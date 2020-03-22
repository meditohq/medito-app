import 'package:Medito/tracking/tracking.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/viewmodel/page.dart';
import 'package:Medito/widgets/pill_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_playout/audio.dart';
import 'package:flutter_playout/player_observer.dart';
import 'package:flutter_playout/player_state.dart';
import 'package:flutter_svg/svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/colors.dart';
import '../viewmodel/list_item.dart';

class PlayerWidget extends StatefulWidget {
  PlayerWidget(
      {Key key,
      this.fileModel,
      this.desiredState,
      this.listItem,
      this.coverColor,
      this.coverArt,
      this.attributions})
      : super(key: key);

  final String coverColor;
  final CoverArt coverArt;
  final Future attributions;
  final Files fileModel;
  final PlayerState desiredState;
  final ListItem listItem;

  @override
  _PlayerWidgetState createState() {
    return _PlayerWidgetState();
  }
}

class _PlayerWidgetState extends State<PlayerWidget> with PlayerObserver {
  Audio _audioPlayer;
  PlayerState audioPlayerState = PlayerState.STOPPED;
  bool _loading = false;

  String licenseTitle;
  String licenseName;
  String licenseURL;
  String sourceUrl;

  Duration duration = Duration(milliseconds: 1);
  Duration currentPlaybackPosition = Duration.zero;

  double eightyPercentOfScreen;

  get isPlaying => audioPlayerState == PlayerState.PLAYING;

  get isPaused =>
      audioPlayerState == PlayerState.PAUSED ||
      audioPlayerState == PlayerState.STOPPED;

  @override
  void dispose() {
    super.dispose();
    stop();
    _audioPlayer.dispose();
  }

  @override
  void initState() {
    super.initState();

    // Init audio player with a callback to handle events
    _audioPlayer = Audio.instance();

    // Listen for audio player events
    listenForAudioPlayerEvents();

    widget.attributions.then((attr) {
      sourceUrl = attr.sourceUrl;
      licenseName = attr.licenseName;
      licenseTitle = attr.title;
      licenseURL = attr.licenseUrl;
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(PlayerWidget oldWidget) {
    if (oldWidget.desiredState != widget.desiredState) {
      _onDesiredStateChanged(oldWidget);
    } else if (oldWidget.fileModel.url != widget.fileModel.url) {
      play();
    }
    super.didUpdateWidget(oldWidget);
  }

  /// The [desiredState] flag has changed so need to update playback to
  /// reflect the new state.
  void _onDesiredStateChanged(PlayerWidget oldWidget) async {
    switch (widget.desiredState) {
      case PlayerState.PLAYING:
        play();
        break;
      case PlayerState.PAUSED:
        pause();
        break;
      case PlayerState.STOPPED:
        pause();
        break;
    }
  }

  @override
  void onPlay() {
    setState(() {
      audioPlayerState = PlayerState.PLAYING;
      _loading = false;
    });
  }

  @override
  void onPause() {
    setState(() {
      audioPlayerState = PlayerState.PAUSED;
    });
  }

  @override
  void onComplete() {
    setState(() {
      audioPlayerState = PlayerState.PAUSED;
      currentPlaybackPosition = Duration.zero;
    });
  }

  @override
  void onTime(int position) {
    setState(() {
      currentPlaybackPosition = Duration(seconds: position);
    });
  }

  @override
  void onSeek(int position, double offset) {
    super.onSeek(position, offset);
  }

  @override
  void onDuration(int duration) {
    if (duration > 0) {
      setState(() {
        this.duration = Duration(milliseconds: duration);
      });
    }
  }

  @override
  void onError(String error) {
    super.onError(error);
  }

  @override
  Widget build(BuildContext context) {
    this.eightyPercentOfScreen = MediaQuery.of(context).size.height *
        0.75; //TODO use fractionallysizedbox

    return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              buildGoBackPill(),
              buildContainerWithRoundedCorners(context),
            ],
          ),
        ));
  }

  Widget buildContainerWithRoundedCorners(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(left: 16, right: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        color: MeditoColors.darkColor,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Flexible(flex: 1, child: buildImageItems()),
          buildPlayItems(),
          Container(
            height: 24,
          ),
        ],
      ),
    );
  }

  Widget buildButtonRow() {
    return Padding(
      padding: const EdgeInsets.only(left: 24.0, right: 24.0),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              height: 48,
              child: FlatButton(
                shape: RoundedRectangleBorder(
                    borderRadius: new BorderRadius.circular(12.0),
                    side: BorderSide(color: Colors.red)),
                child: _loading
                    ? buildCircularProgressIndicator()
                    : Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: MeditoColors.darkColor,
                      ),
                color: MeditoColors.lightColor,
                onPressed: () {
                  if (isPlaying) {
                    pause();
                  } else {
                    play();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCircularProgressIndicator() {
    return Center(
      child: SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(MeditoColors.darkColor),
        ),
      ),
    );
  }

  Widget buildSlider() {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, right: 8.0),
      child: SliderTheme(
        data: SliderThemeData(
          activeTrackColor: MeditoColors.lightColor,
          inactiveTrackColor: MeditoColors.darkBGColor,
          thumbColor: MeditoColors.lightColor,
          trackHeight: 4,
        ),
        child: Slider(
          value: currentPlaybackPosition?.inMilliseconds?.toDouble() ?? 0.0,
          min: 0,
          max: duration.inMilliseconds.toDouble(),
          onChanged: (double value) {
            seekTo(value);
          },
        ),
      ),
    );
  }

  // Request audio play
  Future<void> play() async {
    setState(() {
      _loading = true;
    });
    // here we send position in case user has scrubbed already before hitting
    // play in which case we want playback to start from where user has
    // requested
    _audioPlayer.play(widget.fileModel.url,
        title: widget.listItem.title,
        subtitle: widget.listItem.description,
        position: currentPlaybackPosition,
        isLiveStream: false);
  }

  // Request audio pause
  Future<void> pause() async {
    _audioPlayer.pause();
    setState(() => audioPlayerState = PlayerState.PAUSED);
  }

  // Request audio stop. this will also clear lock screen controls
  Future<void> stop() async {
    _audioPlayer.reset();

    setState(() {
      audioPlayerState = PlayerState.STOPPED;
      currentPlaybackPosition = Duration.zero;
    });
  }

  // Seek to a point in seconds
  Future<void> seekTo(double milliseconds) async {
    setState(() {
      currentPlaybackPosition = Duration(milliseconds: milliseconds.toInt());
    });
    _audioPlayer.seekTo(milliseconds / 1000);
  }

  void pressed() {
    print('pressss');
  }

  Widget buildGoBackPill() {
    return Padding(
      padding: EdgeInsets.only(left: 16, bottom: 8),
      child: GestureDetector(
          onTap: () {
            stop();
            Tracking.trackEvent(Tracking.BREADCRUMB, Tracking.BREADCRUMB_TAPPED,
                widget.listItem.id);
            Navigator.pop(context);
          },
          child: Container(
            padding: getEdgeInsets(1, 1),
            decoration: getBoxDecoration(1, 1, color: MeditoColors.darkBGColor),
            child: getTextLabel("< Go back", 1, 1, context),
          )),
    );
  }

  Widget buildImage() {
    return Row(
      children: <Widget>[
        Expanded(
          child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16)),
                color: Color(int.parse(widget.coverColor?.replaceFirst('#', ''),
                    radix: 16)),
              ),
              child: SvgPicture.network(
                widget.coverArt.url,
              )),
        ),
      ],
    );
  }

  Widget buildTitle() {
    return Row(
      children: <Widget>[
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(
                top: 24, left: 24.0, right: 24, bottom: 24),
            child: Text(
              widget.listItem.title + 'dfg dsfg sdfjkgh jsdfg 234 23 ',
              style: Theme.of(context).textTheme.title.copyWith(fontSize: 22),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildTimeLabelsRow() {
    return Padding(
      padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(_playbackPositionString(),
                style: Theme.of(context).textTheme.display2),
            Text(_playbackRemainingString(),
                style: Theme.of(context).textTheme.display2)
          ]),
    );
  }

  Widget buildLowerText(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Text(getLoremLong(),
          //widget.listItem.contentText,
          style: Theme.of(context).textTheme.display4),
    );
  }

  String _playbackPositionString() {
    return formatDuration(currentPlaybackPosition);
  }

  String _playbackRemainingString() {
    return formatDuration(Duration(
        milliseconds:
            duration.inMilliseconds - currentPlaybackPosition.inMilliseconds));
  }

  Widget buildAttributionsView() {
    return Container(
      padding: EdgeInsets.only(top: 8, bottom: 8, left: 16, right: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(2)),
        color: MeditoColors.darkColor,
      ),
      child: new RichText(
        text: new TextSpan(
          children: [
            new TextSpan(
              text: 'Audio from '.toUpperCase(),
              style: new TextStyle(color: MeditoColors.lightColor),
            ),
            new TextSpan(
              text: licenseName?.toUpperCase(),
              style: new TextStyle(
                  color: MeditoColors.lightColor, fontWeight: FontWeight.bold),
              recognizer: new TapGestureRecognizer()
                ..onTap = () {
                  launch(sourceUrl);
                },
            ),
            new TextSpan(
              text: ' / License: '.toUpperCase(),
              style: new TextStyle(color: MeditoColors.lightColor),
            ),
            new TextSpan(
              text: licenseTitle?.toUpperCase(),
              style: new TextStyle(
                  color: MeditoColors.lightColor, fontWeight: FontWeight.bold),
              recognizer: new TapGestureRecognizer()
                ..onTap = () {
                  launch(licenseURL);
                },
            ),
          ],
        ),
      ),
    );
  }

  Widget buildPlayItems() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        buildSlider(),
        buildTimeLabelsRow(),
        buildButtonRow(),
      ],
    );
  }

  Widget buildImageItems() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[buildImage(), buildTitle()],
    );
  }
}
