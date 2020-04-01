import 'package:Medito/data/page.dart';
import 'package:Medito/tracking/tracking.dart';
import 'package:Medito/utils/utils.dart';
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
  PlayerWidget({Key key,
    this.fileModel,
    this.desiredState,
    this.listItem,
    this.coverColor,
    this.title,
    this.coverArt,
    this.attributions,
    this.description})
      : super(key: key);

  final String coverColor;
  final String description;
  final CoverArt coverArt;
  final Future attributions;
  final Files fileModel;
  final PlayerState desiredState;
  final String title;
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

  double widthOfScreen;

  get isPlaying => audioPlayerState == PlayerState.PLAYING;

  get isPaused =>
      audioPlayerState == PlayerState.PAUSED ||
          audioPlayerState == PlayerState.STOPPED;

  @override
  void dispose() {
    Tracking.trackEvent(Tracking.BREADCRUMB, Tracking.PLAYER_BREADCRUMB_TAPPED,
        widget.fileModel.id);

    if (audioPlayerState != PlayerState.STOPPED) {
      stop();
    }
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void initState() {
    Tracking.trackEvent(Tracking.PLAYER, Tracking.SCREEN_LOADED, widget.fileModel.id);

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
    play();
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
    if (this.mounted)
      setState(() {
        audioPlayerState = PlayerState.PLAYING;
        _loading = false;
      });
  }

  @override
  void onPause() {
    if (this.mounted)
      setState(() {
        audioPlayerState = PlayerState.PAUSED;
      });
  }

  @override
  void onComplete() {
    Tracking.trackEvent(Tracking.PLAYER, Tracking.PLAYER_TAPPED,
        Tracking.AUDIO_COMPLETED + widget.listItem.id);

        if (this.mounted)
    setState(() {
      audioPlayerState = PlayerState.PAUSED;
      currentPlaybackPosition = Duration.zero;
    });
  }

  @override
  void onTime(int position) {
    if (this.mounted)
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
    if (this.mounted && duration > 0) {
      setState(() {
        this.duration = Duration(milliseconds: duration);
      });
    }
  }

  @override
  void onError(String error) {
    Tracking.trackEvent(
        Tracking.PLAYER, Tracking.PLAYER_TAPPED, Tracking.AUDIO_ERROR + widget.listItem.id);

    super.onError(error);
  }

  @override
  Widget build(BuildContext context) {
    this.widthOfScreen = MediaQuery
        .of(context)
        .size
        .width;

    return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: <Widget>[
            Positioned(
                bottom: 0,
                child: Container(
                    width: widthOfScreen,
                    height: 35,
                    color: MeditoColors.darkBGColor)),
            Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    buildGoBackPill(),
                    buildContainerWithRoundedCorners(context),
                  ],
                ),
              ),
            ),
            buildBottomSheet(),
          ],
        ));
  }

  Widget buildBottomSheet() {
    return SafeArea(
      bottom: false,
      child: DraggableScrollableSheet(
        initialChildSize: 0.07,
        minChildSize: 0.07,
        builder: (BuildContext context, ScrollController scrollController) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8), topRight: Radius.circular(8)),
              color: MeditoColors.darkBGColor,
            ),
            child: ListView.builder(
              controller: scrollController,
              itemCount: 2,
              itemBuilder: (BuildContext context, int index) {
                switch (index) {
                  case 0:
                    return Visibility(
                      visible: widget.listItem.contentText != '',
                      child: Column(
                        children: <Widget>[
                          Visibility(
                            visible: widget.listItem.contentText != null,
                            child: Center(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius:
                                  BorderRadius.all(Radius.circular(16)),
                                  color: MeditoColors.lightColorLine,
                                ),
                                margin: EdgeInsets.only(top: 16, bottom: 16),
                                height: 4,
                                width: 48,
                              ),
                            ),
                          ),
                          Visibility(
                            visible: widget.listItem.contentText != null,
                            child: Center(
                                child: Text(
                                  'MORE DETAILS',
                                  style: Theme
                                      .of(context)
                                      .textTheme
                                      .body2,
                                )),
                          ),
                          widget.listItem.contentText != null
                              ? Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              widget.listItem.contentText,
                              style: Theme
                                  .of(context)
                                  .textTheme
                                  .display3,
                            ),
                          )
                              : Container(),
                        ],
                      ),
                    );
                  case 1:
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Center(child: buildAttributionsView()),
                    );
                }

                return Container();
              },
            ),
          );
        },
      ),
    );
  }

  Widget buildContainerWithRoundedCorners(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(left: 16, right: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        color: MeditoColors.darkBGColor,
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
                ),
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
          inactiveTrackColor: MeditoColors.darkColor,
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
    Tracking.trackEvent(
        Tracking.PLAYER, Tracking.PLAYER_TAPPED, Tracking.AUDIO_PLAY + widget.fileModel.id);

    if (this.mounted)
      setState(() {
        _loading = true;
      });
    // here we send position in case user has scrubbed already before hitting
    // play in which case we want playback to start from where user has
    // requested
    _audioPlayer
        .play(widget.fileModel.url,
        title: widget.title,
        subtitle: widget.description == null ? '' : widget.description,
        position: currentPlaybackPosition,
        isLiveStream: false)
        .catchError((onError) {
      print(onError);
    });
  }

  // Request audio pause
  Future<void> pause() async {
    Tracking.trackEvent(
        Tracking.PLAYER, Tracking.PLAYER_TAPPED, Tracking.AUDIO_PAUSED + widget.fileModel.id);

    _audioPlayer.pause();
    if (this.mounted) setState(() => audioPlayerState = PlayerState.PAUSED);
  }

  // Request audio stop. this will also clear lock screen controls
  Future<void> stop() async {
//    _audioPlayer.reset();
    Tracking.trackEvent(
        Tracking.PLAYER, Tracking.PLAYER_TAPPED, Tracking.AUDIO_STOPPED + widget.fileModel.id);


    if (this.mounted)
      setState(() {
        audioPlayerState = PlayerState.STOPPED;
        currentPlaybackPosition = Duration.zero;
      });
  }

  // Seek to a point in seconds
  Future<void> seekTo(double milliseconds) async {
    Tracking.trackEvent(Tracking.PLAYER, Tracking.PLAYER_TAPPED,
        Tracking.AUDIO_SEEK + '$milliseconds :'  + widget.fileModel.id);

    setState(() {
      currentPlaybackPosition = Duration(milliseconds: milliseconds.toInt());
    });
    _audioPlayer.seekTo(milliseconds / 1000);
  }

  Widget buildGoBackPill() {
    return Padding(
      padding: EdgeInsets.only(left: 16, bottom: 8, top: 24),
      child: GestureDetector(
          onTap: () {
            stop();
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
          child: SizedBox(
            width: 200,
            height: 200,
            child: Container(
                margin: EdgeInsets.only(top: 24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: parseColor(widget.coverColor),
                ),
                child: SvgPicture.network(
                  widget.coverArt.url,
                )),
          ),
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
              widget.title,
              style: Theme
                  .of(context)
                  .textTheme
                  .title,
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
                style: Theme
                    .of(context)
                    .textTheme
                    .display2),
            Text(_playbackRemainingString(),
                style: Theme
                    .of(context)
                    .textTheme
                    .display2)
          ]),
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
      padding: EdgeInsets.only(top: 0, bottom: 8, left: 16, right: 16),
      child: new RichText(
        text: new TextSpan(
          children: [
            new TextSpan(
              text: 'Audio from '.toUpperCase(),
              style: Theme
                  .of(context)
                  .textTheme
                  .display4,
            ),
            new TextSpan(
              text: licenseTitle?.toUpperCase(),
              style: Theme
                  .of(context)
                  .textTheme
                  .body2,
              recognizer: new TapGestureRecognizer()
                ..onTap = () {
                  launch(sourceUrl);
                },
            ),
            new TextSpan(
              text: ' / License: '.toUpperCase(),
              style: Theme
                  .of(context)
                  .textTheme
                  .display4,
            ),
            new TextSpan(
              text: licenseName?.toUpperCase(),
              style: Theme
                  .of(context)
                  .textTheme
                  .body2,
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
