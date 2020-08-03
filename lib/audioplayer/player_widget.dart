/*This file is part of Medito App.

Medito App is free software: you can redistribute it and/or modify
it under the terms of the Affero GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Medito App is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
Affero GNU General Public License for more details.

You should have received a copy of the Affero GNU General Public License
along with Medito App. If not, see <https://www.gnu.org/licenses/>.*/

import 'package:Medito/audioplayer/player_utils.dart';
import 'package:Medito/data/page.dart';
import 'package:Medito/tracking/tracking.dart';
import 'package:Medito/utils/stats_utils.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/viewmodel/model/list_item.dart';
import 'package:Medito/widgets/pill_utils.dart';
import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../utils/colors.dart';

class PlayerWidget extends StatefulWidget {
  PlayerWidget(
      {Key key,
      this.fileModel,
      this.listItem,
      this.coverColor,
      this.title,
      this.coverArt,
      this.attributions,
      this.description,
      this.bgMusicPath,
      this.textColor})
      : super(key: key);

  final String bgMusicPath;
  final String textColor;
  final String coverColor;
  final String description;
  final CoverArt coverArt;
  final Future attributions;
  final Files fileModel;
  final String title;
  final ListItem listItem;

  @override
  _PlayerWidgetState createState() {
    return _PlayerWidgetState();
  }
}

class _PlayerWidgetState extends State<PlayerWidget> {
  String licenseTitle;
  String licenseName;
  String licenseURL;
  String sourceUrl;
  bool showDownloadButton;

  Duration _duration;
  Duration _position;

  double widthOfScreen;

  bool _loading = true;
  bool _isPlaying = true;
  bool _updatedStats = false;

  var _initialBgVolume = .8;
  String donateUrl = "https://meditofoundation.org/donate/";
  Duration _bgDuration;

  final _assetsAudioPlayer = AssetsAudioPlayer.newPlayer();
  final _bgAssetsAudioPlayer1 = AssetsAudioPlayer.newPlayer();
  final _bgAssetsAudioPlayer2 = AssetsAudioPlayer.newPlayer();

  @override
  void dispose() {
    Tracking.trackEvent(Tracking.BREADCRUMB, Tracking.PLAYER_BREADCRUMB_TAPPED,
        widget.fileModel.id);

    stop();
    super.dispose();
  }

  @override
  void initState() {
    Tracking.trackEvent(
        Tracking.PLAYER, Tracking.SCREEN_LOADED, widget.fileModel.id);

    super.initState();

    widget.attributions.then((attr) {
      sourceUrl = attr.sourceUrl;
      licenseName = attr.licenseName;
      licenseTitle = attr.title;
      showDownloadButton = attr.downloadButton;
      licenseURL = attr.licenseUrl;
      getDownload(widget.fileModel.filename).then((data) {
        if (data == null)
          _loadRemote();
        else {
          _loadLocal(data);
        }
      });

      if (widget.bgMusicPath != null && widget.bgMusicPath.isNotEmpty) {
        loadBackground();
      }
    });
  }

  void _loadLocal(String data) {
    try {
      _assetsAudioPlayer.open(
          Audio.file(data)..updateMetas(title: widget.title),
          showNotification: true,
          headPhoneStrategy: HeadPhoneStrategy.pauseOnUnplug,
          notificationSettings: _getNotificationSettings(),
          audioFocusStrategy:
              AudioFocusStrategy.request(resumeAfterInterruption: true));
      _onReady();
    } catch (t) {
      print('load local error: ' + t);
    }
  }

  Future<void> _loadRemote() async {
    try {
      await _assetsAudioPlayer.open(
        Audio.network(
          widget.fileModel.url.replaceAll(' ', '%20'),
        )..updateMetas(title: widget.title),
        showNotification: true,
        audioFocusStrategy:
            AudioFocusStrategy.request(resumeAfterInterruption: true),
        notificationSettings: _getNotificationSettings(),
      );
      _onReady();
    } catch (t) {
      //mp3 unreachable
      print('load remote error: ' + t);
    }
  }

  void loadBackground() {
    _bgAssetsAudioPlayer1.open(
      Audio.file(widget.bgMusicPath),
      volume: _initialBgVolume,
      loopMode: LoopMode.none,
      audioFocusStrategy:
          AudioFocusStrategy.request(resumeAfterInterruption: true),
      notificationSettings: _getNotificationSettings(),
    );

    _bgAssetsAudioPlayer2
        .open(
          Audio.file(widget.bgMusicPath),
          volume: _initialBgVolume,
          loopMode: LoopMode.none,
          audioFocusStrategy:
              AudioFocusStrategy.request(resumeAfterInterruption: true),
          notificationSettings: _getNotificationSettings(),
        )
        .then((value) {
          return _bgAssetsAudioPlayer2.stop();
        });

    try {
      _bgAssetsAudioPlayer1.onReadyToPlay.listen((audio) {
        if (this.mounted) {
          setState(() {
            _loading = false;
            _bgDuration = audio?.duration ?? Duration(seconds: 0);
            _observeBgAudio();
          });
        }
      });
    } catch (t) {
      print('bg duartion error: ' + t);
    }
  }

  void _onReady() {
    try {
      _assetsAudioPlayer.onReadyToPlay.listen((audio) {
        if (this.mounted) {
          setState(() {
            _loading = false;
            _duration = audio?.duration ?? Duration(seconds: 0);
          });
        }
      });
    } catch (t) {
      print('onready error: ' + t);
    }
  }

  void showDonateDialog() async {
    var numSessions = await getNumSessionsInt();
    if (numSessions > 0 && numSessions % 5 == 0) {
      Future<bool> userAct = showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: MeditoColors.darkBGColor,
              shape: RoundedRectangleBorder(
                borderRadius: new BorderRadius.circular(12.0),
              ),
              title: Text(
                  "Well done for completing " +
                      numSessions.toString() +
                      " sessions!",
                  style: TextStyle(color: MeditoColors.lightTextColor)),
              content: Text(
                  "We believe that mindfulness and meditation can transform our lives, and no one should have to pay for it. Please consider donating to show our volunteers that their work matters.",
                  style: TextStyle(color: MeditoColors.lightTextColor)),
              actions: <Widget>[
                FlatButton(
                  padding: EdgeInsets.only(left: 16.0, right: 16.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: new BorderRadius.circular(12.0),
                  ),
                  color: widget.coverColor != null
                      ? parseColor(widget.coverColor)
                      : MeditoColors.lightColor,
                  child:
                      Text('Dismiss', style: TextStyle(color: getTextColor())),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
                FlatButton(
                  padding: EdgeInsets.only(left: 16.0, right: 16.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: new BorderRadius.circular(12.0),
                  ),
                  color: widget.coverColor != null
                      ? parseColor(widget.coverColor)
                      : MeditoColors.lightColor,
                  child:
                      Text('Donate', style: TextStyle(color: getTextColor())),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                ),
              ],
            );
          });
      if (await userAct != null && await userAct) {
        launchUrl(donateUrl);
      } else {
        Navigator.popUntil(context, ModalRoute.withName("/nav"));
      }
    }
  }

  void updateStats() {
    if (!_updatedStats) {
      markAsListened(widget.listItem.id);
      incrementNumSessions();
      updateStreak();
      _updatedStats = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    this.widthOfScreen = MediaQuery.of(context).size.width;

    return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: <Widget>[
            Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        buildGoBackPill(),
                      ],
                    ),
                    buildContainerWithRoundedCorners(context),
                    getAttrWidget(context, licenseTitle, sourceUrl, licenseName,
                        licenseURL),
                  ],
                ),
              ),
            ),
          ],
        ));
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
            height: 16,
          ),
        ],
      ),
    );
  }

  Widget buildButtonRow() {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              height: 48,
              child: FlatButton(
                shape: RoundedRectangleBorder(
                  borderRadius: new BorderRadius.circular(12.0),
                ),
                child: buildIcon(),
                color: widget.coverColor != null
                    ? parseColor(widget.coverColor)
                    : MeditoColors.lightColor,
                onPressed: () {
                  if (_assetsAudioPlayer.isPlaying.value) {
                    _isPlaying = false;
                    pause();
                  } else {
                    _isPlaying = true;
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

  Widget buildIcon() {
    return _loading
        ? SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(getTextColor())),
          )
        : Icon(
            _isPlaying ? Icons.pause : Icons.play_arrow,
            color: getTextColor(),
          );
  }

  Color getTextColor() {
    return widget.textColor == null || widget.textColor.isEmpty
        ? MeditoColors.darkColor
        : parseColor(widget.textColor);
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
    return PlayerBuilder.currentPosition(
        player: _assetsAudioPlayer,
        builder: (context, position) {
          var pos = position?.inSeconds?.toDouble() ?? 0;
          var dur = _duration?.inSeconds?.toDouble() ?? 0;

          _onTick(dur, pos);

          if (pos > dur) {
            return Container();
          } else {
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
                  value: pos,
                  max: dur,
                  onChanged: (seconds) {
                    setState(() {
                      _assetsAudioPlayer
                          .seek(Duration(seconds: seconds.toInt()));
                      _position = Duration(seconds: seconds.toInt());
                    });
                  },
                ),
              ),
            );
          }
        });
  }

  void _onTick(double dur, double pos) {
    _changeBackgroundVolumeOnMainTrackPosition(dur, pos);
    if (dur > 0 && pos > dur - 15 && pos < dur - 0) {
      updateStats();

      if (!_updatedStats) {
        Tracking.trackEvent(Tracking.PLAYER, Tracking.PLAYER_TAPPED,
            Tracking.AUDIO_COMPLETED + widget.listItem.id);
      }

      if (pos >= dur - 2) {
        // so almost at the end
        showDonateDialog();
      }
    }
  }

  // Request audio play
  Future<void> play() async {
    _assetsAudioPlayer.play();
    _bgAssetsAudioPlayer1.play();

    if (this.mounted) {
      setState(() {
        _isPlaying = true;
      });
    }

    Tracking.trackEvent(Tracking.PLAYER, Tracking.PLAYER_TAPPED,
        Tracking.AUDIO_PLAY + widget.fileModel.id);
  }

  // Request audio pause
  Future<void> pause() async {
    setState(() {
      _isPlaying = false;
    });
    _assetsAudioPlayer.pause();
    _bgAssetsAudioPlayer1.stop();

    Tracking.trackEvent(Tracking.PLAYER, Tracking.PLAYER_TAPPED,
        Tracking.AUDIO_PAUSED + widget.fileModel.id);
  }

  // Request audio stop. this will also clear lock screen controls
  void stop() async {
    _assetsAudioPlayer.stop();
    _assetsAudioPlayer.dispose();
    _bgAssetsAudioPlayer1.stop();
    _bgAssetsAudioPlayer1.dispose();
    _bgAssetsAudioPlayer2.stop();
    _bgAssetsAudioPlayer2.dispose();

    updateMinuteCounter(_position?.inSeconds);

    Tracking.trackEvent(Tracking.PLAYER, Tracking.PLAYER_TAPPED,
        Tracking.AUDIO_STOPPED + widget.fileModel.id);
  }

  Widget buildGoBackPill() {
    return Padding(
      padding: EdgeInsets.only(left: 16, bottom: 8, top: 24),
      child: GestureDetector(
          onTap: () {
            Navigator.popUntil(context, ModalRoute.withName("/nav"));
          },
          child: Container(
            padding: getEdgeInsets(1, 1),
            decoration: getBoxDecoration(1, 1, color: MeditoColors.darkBGColor),
            child: getTextLabel("✗ Close", 1, 1, context),
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
                padding: EdgeInsets.all(22),
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12)),
                  color: parseColor(widget.coverColor),
                ),
                child: getNetworkImageWidget(widget.coverArt.url)),
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
              style: Theme.of(context).textTheme.headline6,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildTimeLabelsRow() {
    return PlayerBuilder.currentPosition(
        player: _assetsAudioPlayer,
        builder: (context, position) {
          return Padding(
            padding:
                const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(_formatDuration(position),
                      style: Theme.of(context).textTheme.headline3),
                  Text(_formatDuration(_duration),
                      style: Theme.of(context).textTheme.headline3)
                ]),
          );
        });
  }

  String _formatDuration(Duration d) {
    if (d == null) return "--:--";
    int minute = d.inMinutes;
    int second = (d.inSeconds >= 60) ? (d.inSeconds % 60) : d.inSeconds;
    String format = ((minute < 10) ? "0$minute" : "$minute") +
        ":" +
        ((second < 10) ? "0$second" : "$second");
    return format;
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

  void onError(var error) {
    print(error.toString());
  }

  void _changeBackgroundVolumeOnMainTrackPosition(double dur, double pos) {
    //volume decreases as it approaches end of track
    var timeLeft = dur - pos;

    var timeToStartDecreasing = _initialBgVolume * 100;
    if (timeLeft < timeToStartDecreasing) {
      var volume = timeLeft / 100;
      _bgAssetsAudioPlayer1.setVolume(volume);
      _bgAssetsAudioPlayer2.setVolume(volume);
    } else {
      _bgAssetsAudioPlayer1.setVolume(_initialBgVolume);
      _bgAssetsAudioPlayer2.setVolume(_initialBgVolume);
    }
  }

  NotificationSettings _getNotificationSettings() {
    return NotificationSettings(
        prevEnabled: false,
        nextEnabled: false,
        stopEnabled: true,
        customStopAction: _customStopAction,
        customPlayPauseAction: _customPlayPauseAction,
        seekBarEnabled: true);
  }

  void _customPlayPauseAction(AssetsAudioPlayer player) {
    if (!_isPlaying) {
      play();
    } else {
      pause();
    }
  }

  void _customStopAction(AssetsAudioPlayer player) {
    _assetsAudioPlayer.stop();
    _assetsAudioPlayer.dispose();
    _bgAssetsAudioPlayer1.stop();
    _bgAssetsAudioPlayer1.dispose();
    _bgAssetsAudioPlayer2.stop();
    _bgAssetsAudioPlayer2.dispose();
    Navigator.of(context).pop(false);
  }

  void _observeBgAudio() {
    _bgAssetsAudioPlayer1.currentPosition.listen((position) {
      print('1 tick' + position.toString());
      if (this.mounted) {
        if (position.inSeconds > 5 &&
            position.inSeconds < 6 &&
            _bgAssetsAudioPlayer2.isPlaying.value) {
          _bgAssetsAudioPlayer2.stop();
          print('2 stopping');
        }

        if (position.inSeconds > _bgDuration.inSeconds - 5 &&
            !_bgAssetsAudioPlayer2.isPlaying.value) {
          _bgAssetsAudioPlayer2.play();
          print('2 starting');
        }
      } else {
        stop();
      }
    });

    _bgAssetsAudioPlayer2.currentPosition.listen((position) {
      print('2 tick' + position.toString());
      if (this.mounted) {
        if (position.inSeconds > 5 &&
            position.inSeconds < 6 &&
            _bgAssetsAudioPlayer1.isPlaying.value) {
          _bgAssetsAudioPlayer1.stop();
          print('1 stopping');
        }
        if (position.inSeconds > _bgDuration.inSeconds - 5 &&
            !_bgAssetsAudioPlayer1.isPlaying.value) {
          _bgAssetsAudioPlayer1.play();
          print('1 starting');
        }
      } else {
        stop();
      }
    });
  }
}
