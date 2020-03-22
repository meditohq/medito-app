import 'package:flutter/material.dart';
import 'package:flutter_playout/audio.dart';
import 'package:flutter_playout/player_observer.dart';
import 'package:flutter_playout/player_state.dart';

class AudioPlayout extends StatefulWidget {
  // Audio url to play
  final String url =
      "https://file-examples.com/wp-content/uploads/2017/11/file_example_MP3_700KB.mp3";

  // Audio track title. this will also be displayed in lock screen controls
  final String title = "MTA International";

  // Audio track subtitle. this will also be displayed in lock screen controls
  final String subtitle = "Reaching The Corners Of The Earth";

  final PlayerState desiredState;

  const AudioPlayout({Key key, this.desiredState}) : super(key: key);

  @override
  _AudioPlayout createState() => _AudioPlayout();
}

class _AudioPlayout extends State<AudioPlayout> with PlayerObserver {
  Audio _audioPlayer;
  PlayerState audioPlayerState = PlayerState.STOPPED;
  bool _loading = false;
  bool _isLive = false;

  Duration duration = Duration(milliseconds: 1);
  Duration currentPlaybackPosition = Duration.zero;

  get isPlaying => audioPlayerState == PlayerState.PLAYING;

  get isPaused =>
      audioPlayerState == PlayerState.PAUSED ||
      audioPlayerState == PlayerState.STOPPED;

  get durationText =>
      duration != null ? duration.toString().split('.').first : '';

  get positionText => currentPlaybackPosition != null
      ? currentPlaybackPosition.toString().split('.').first
      : '';

  @override
  void initState() {
    super.initState();

    // Init audio player with a callback to handle events
    _audioPlayer = Audio.instance();

    // Listen for audio player events
    listenForAudioPlayerEvents();
  }

  @override
  void didUpdateWidget(AudioPlayout oldWidget) {
    if (oldWidget.desiredState != widget.desiredState) {
      _onDesiredStateChanged(oldWidget);
    } else if (oldWidget.url != widget.url) {
      play();
    }
    super.didUpdateWidget(oldWidget);
  }

  /// The [desiredState] flag has changed so need to update playback to
  /// reflect the new state.
  void _onDesiredStateChanged(AudioPlayout oldWidget) async {
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
    if (duration <= 0) {
      setState(() {
        _isLive = true;
      });
    } else {
      setState(() {
        _isLive = false;
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
    return Container(
      color: Colors.grey[900],
      child: _buildPlayerControls(),
    );
  }

  Widget _buildPlayerControls() {
    return Container(
      color: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                padding: EdgeInsets.fromLTRB(0.0, 11.0, 0.0, 0.0),
                margin: EdgeInsets.all(7.0),
                child: Stack(
                  children: <Widget>[
                    IconButton(
                      padding: EdgeInsets.all(0.0),
                      splashColor: Colors.transparent,
                      icon: Icon(
                        isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                      ),
                      onPressed: () {
                        if (isPlaying) {
                          pause();
                        } else {
                          play();
                        }
                      },
                    ),
                    _loading
                        ? Positioned.fill(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Container(),
                  ],
                ),
              ),
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      padding: EdgeInsets.fromLTRB(7.0, 11.0, 5.0, 3.0),
                      child: Text(widget.title,
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[100])),
                    ),
                    Container(
                      padding: EdgeInsets.fromLTRB(7.0, 0.0, 5.0, 0.0),
                      child: Text(widget.subtitle,
                          style: TextStyle(fontSize: 19, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Container(
            height: 15.0,
          ),
          _isLive
              ? Container(
                  child: Center(
                    child: MaterialButton(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            Icons.fiber_smart_record,
                            color: Colors.redAccent,
                          ),
                          Text(
                            " LIVE",
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ],
                      ),
                      onPressed: () {},
                    ),
                  ),
                )
              : Slider(
                  activeColor: Colors.white,
                  value: currentPlaybackPosition?.inMilliseconds?.toDouble() ??
                      0.0,
                  onChanged: (double value) {
                    seekTo(value);
                  },
                  min: 0.0,
                  max: duration.inMilliseconds.toDouble(),
                ),
          _isLive
              ? Container()
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Container(),
                    Container(
                      padding: EdgeInsets.fromLTRB(20, 5, 20, 10),
                      child: Text(
                        _playbackPositionString(),
                        style: Theme.of(context)
                            .textTheme
                            .body1
                            .copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                )
        ],
      ),
    );
  }

  String _playbackPositionString() {
    var currentPosition = Duration(
        seconds: duration.inSeconds - currentPlaybackPosition.inSeconds);

    return currentPosition.toString().split('.').first;
  }

  // Request audio play
  Future<void> play() async {
    setState(() {
      _loading = true;
    });
    // here we send position in case user has scrubbed already before hitting
    // play in which case we want playback to start from where user has
    // requested
    _audioPlayer.play(widget.url,
        title: widget.title,
        subtitle: widget.subtitle,
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

  @override
  void dispose() {
    if (mounted) {
      _audioPlayer.dispose();
    }
    super.dispose();
  }
}
