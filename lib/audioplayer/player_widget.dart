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

import 'dart:typed_data';

import 'package:Medito/audioplayer/player_utils.dart';
import 'package:Medito/data/page.dart';
import 'package:Medito/tracking/tracking.dart';
import 'package:Medito/utils/stats_utils.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/pill_utils.dart';
import 'package:audiofileplayer/audio_system.dart';
import 'package:audiofileplayer/audiofileplayer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../utils/colors.dart';
import 'package:Medito/viewmodel/model/list_item.dart';

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
      this.textColor})
      : super(key: key);

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
  String _error;
  Duration _position;

  double widthOfScreen;

  bool _loading = true;
  bool _isPlaying = false;
  bool _updatedStats = false;
  Audio _audio;

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
          loadRemote();
        else {
          loadLocal(data);
        }

        AudioSystem.instance.addMediaEventListener(_mediaEventListener);
        play();
      });
    });
  }

  void loadLocal(String data) {
    _audio = Audio.loadFromAbsolutePath(data,
        playInBackground: true,
        // Called when audio has finished playing.
        onComplete: () => onComplete(),
        // Called when audio has loaded and knows its duration.
        onDuration: (double durationSeconds) {
          _duration = Duration(seconds: durationSeconds.toInt());
          _loading = false;
        },
        // Called repeatedly with updated playback position.
        onPosition: (double positionSeconds) {
          onTime(positionSeconds);
        });
  }

  void loadRemote() {
    //todo remove this replaceAll later
    _audio =
        Audio.loadFromRemoteUrl(widget.fileModel.url.replaceAll(' ', '%20'),
            playInBackground: true,
            // Called when audio has finished playing.
            onComplete: () => onComplete(),
            // Called when audio has loaded and knows its duration.
            onDuration: (double durationSeconds) {
              _duration = Duration(seconds: durationSeconds.toInt());
              _loading = false;
            },
            // Called repeatedly with updated playback position.
            onPosition: (double positionSeconds) => onTime(positionSeconds));
  }

  void _mediaEventListener(MediaEvent mediaEvent) {
    final MediaActionType type = mediaEvent.type;
    if (type == MediaActionType.play) {
      play();
    } else if (type == MediaActionType.pause) {
      pause();
    } else if (type == MediaActionType.playPause) {
      _isPlaying ? pause() : play();
    } else if (type == MediaActionType.stop) {
      stop();
    } else if (type == MediaActionType.seekTo) {
      _audio.seek(mediaEvent.seekToPositionSeconds);
      AudioSystem.instance
          .setPlaybackState(true, mediaEvent.seekToPositionSeconds);
    }
  }

  void onComplete() {
    if (this.mounted) {
      setState(() {
        _isPlaying = false;
      });
    }

    if (!_updatedStats) {
      updateStats();
    }

    Tracking.trackEvent(Tracking.PLAYER, Tracking.PLAYER_TAPPED,
        Tracking.AUDIO_COMPLETED + widget.listItem.id);
  }

  void onTime(double positionSeconds) {
    if (this.mounted) {
      _position = Duration(seconds: positionSeconds.toInt());
      _isPlaying = true;
      setState(() {});

      if (_position.inSeconds > _duration.inSeconds - 15 &&
          _position.inSeconds < _duration.inSeconds - 10 &&
          !_updatedStats) {
        updateStats();
      }
    }
  }

  void updateStats() {
    markAsListened(widget.listItem.id);
    incrementNumSessions();
    updateStreak();
    _updatedStats = true;
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
                  if (_isPlaying) {
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

  Widget buildIcon() {
    return _loading
        ? SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(getTextColor())),
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
    AudioSystem.instance
        .setPlaybackState(true, _position?.inSeconds?.toDouble() ?? 0);

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
          value: _position?.inSeconds?.toDouble() ?? 0,
          max: _duration?.inSeconds?.toDouble() ?? 0,
          onChanged: (seconds) {
            setState(() {
              _audio.seek(seconds);
              _position = Duration(seconds: seconds.toInt());
            });
          },
        ),
      ),
    );
  }

  // Request audio play
  Future<void> play() async {
    _audio.resume();

    final Uint8List imageBytes = await generateImageBytes();
    AudioSystem.instance.setMetadata(AudioMetadata(
        title: widget.title, artist: licenseTitle, artBytes: imageBytes));
    AudioSystem.instance
        .setPlaybackState(true, _position?.inSeconds?.toDouble() ?? 0);

    AudioSystem.instance.setAndroidNotificationButtons(<dynamic>[
      AndroidMediaButtonType.pause,
    ]);

    AudioSystem.instance.setSupportedMediaActions(<MediaActionType>{
      MediaActionType.playPause,
      MediaActionType.pause,
      MediaActionType.stop,
    }, skipIntervalSeconds: 30);

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
    _audio.pause();
    AudioSystem.instance
        .setPlaybackState(false, _position?.inSeconds?.toDouble() ?? 0);

    AudioSystem.instance.setAndroidNotificationButtons(<dynamic>[
      AndroidMediaButtonType.play,
    ]);

    AudioSystem.instance.setSupportedMediaActions(<MediaActionType>{
      MediaActionType.playPause,
      MediaActionType.play,
      MediaActionType.stop,
    }, skipIntervalSeconds: 30);

    Tracking.trackEvent(Tracking.PLAYER, Tracking.PLAYER_TAPPED,
        Tracking.AUDIO_PAUSED + widget.fileModel.id);
  }

  // Request audio stop. this will also clear lock screen controls
  void stop() async {
    if (_audio != null) {
      _audio
        ..pause()
        ..dispose();
    }

    AudioSystem.instance.removeMediaEventListener(_mediaEventListener);
    AudioSystem.instance.stopBackgroundDisplay();

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
              style: Theme.of(context).textTheme.title,
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
            Text(_formatDuration(_position),
                style: Theme.of(context).textTheme.display2),
            Text(_formatDuration(_duration),
                style: Theme.of(context).textTheme.display2)
          ]),
    );
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
}
