import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import 'audiofileplayer.dart';

final Logger _logger = Logger('audio_system');

const String setSupportedMediaActionsMethod = 'setSupportedMediaActions';
const String mediaActionsKey = 'mediaActions';
const String setAndroidMediaButtonsMethod = 'setAndroidMediaButtons';
const String mediaButtonsKey = 'mediaButtons';
const String mediaCompactIndicesKey = 'mediaCompactIndices';
const String stopBackgroundDisplayMethod = 'stopBackgroundDisplay';

// Constants for iOS category.
const String iosAudioCategoryMethod = 'iosAudioCategory';
const String iosAudioCategoryKey = 'iosAudioCategory';
const String iosAudioCategoryAmbientSolo = 'iosAudioCategoryAmbientSolo';
const String iosAudioCategoryAmbientMixed = 'iosAudioCategoryAmbientMixed';
const String iosAudioCategoryPlayback = 'iosAudioCategoryPlayback';

// Constants for [setPlaybackState].
const String setPlaybackStateMethod = 'setPlaybackState';
const String playbackIsPlayingKey = 'playbackIsPlaying';
const String playbackPositionSeconds = 'playbackPositionSeconds';

// Constants for [AudioMetadata].
const String setMetadataMethod = 'setMetadata';
const String metadataIdKey = 'metadataId';
const String metadataTitleKey = 'metadataTitle';
const String metadataAlbumKey = 'metadataAlbum';
const String metadataArtistKey = 'metadataArtist';
const String metadataGenreKey = 'metadataGenre';
const String metadataDurationSecondsKey = 'metadataDurationSeconds';
const String metadataArtBytesKey = 'metadataArtBytes';

/// Represents audio playback category on iOS.
///
/// An 'ambient' category should be used for tasks like game audio, whereas
/// the [playback] category should be used for tasks like music player playback.
///
/// Note that for background audio to work, the [playback] category must be
/// used, and the [shouldPlayWhileAppPaused] flag must also be set.
///
/// See
/// https://developer.apple.com/documentation/avfoundation/avaudiosessioncategory
/// for more information.
enum IosAudioCategory {
  /// Audio is silenced by screen lock and the silent switch; audio will not mix
  /// with other apps' audio.
  ambientSolo,

  /// Audio is silenced by screen lock and the silent switch; audio will mix
  /// with other apps' (mixable) audio.
  ambientMixed,

  /// Audio is not silenced by screen lock or silent switch; audio will not mix
  /// with other apps' audio.
  ///
  /// The default value.
  playback
}

/// A button to be added to the Android notification display via
/// [setAndroidMediaButtons].
///
/// These are the 'built-in' buttons, with icons provided by this plugin. Users
/// may add additional custom buttons with [AndroidCustomMediaButton].
///
/// These will yield [MediaEvent]s with the equivalent [MediaActionType].
enum AndroidMediaButtonType {
  stop,
  pause,
  play,
  next,
  previous,
  seekForward,
  seekBackward,
}

/// A custom button to be added to the Android notification display via
/// [setAndroidMediaButtons].
class AndroidCustomMediaButton {
  const AndroidCustomMediaButton(
      this.title, this.eventId, this.drawableResource);

  final String title;

  /// A unique identifier for the button, which will be returned the
  /// [MediaEvent.customEventId].
  final String eventId;

  /// The name of the Android icon; must be in the Android project's "drawable"
  /// resource folder.
  final String drawableResource;
}

/// Metadata, used for display in the OS background audio system.
class AudioMetadata {
  const AudioMetadata({
    this.id,
    this.title,
    this.album,
    this.artist,
    this.genre,
    this.durationSeconds,
    this.artBytes,
  });
  final String id;
  final String title;
  final String artist;
  final String album;
  final String genre;
  final double durationSeconds;
  final Uint8List artBytes;
}

/// Sends information to the OS's background audio system.
///
/// Only call these methods if you have an [Audio] to play in the background,
/// and you wish to inform the OS on properties for display/interaction, i.e.
/// showing metadata, and supporting interaction from the lockscreen/
/// control-center (iOS), notification (Android), or external controllers like
/// bluetooth, watch, auto.
class AudioSystem {
  AudioSystem._internal();

  static final AudioSystem _instance = AudioSystem._internal();
  static AudioSystem get instance => _instance;

  /// Send media events to the client for handling.
  final Set<ValueChanged<MediaEvent>> _mediaEventListeners =
      <ValueChanged<MediaEvent>>{};

  void addMediaEventListener(ValueChanged<MediaEvent> listener) =>
      _mediaEventListeners.add(listener);

  void removeMediaEventListener(ValueChanged<MediaEvent> listener) =>
      _mediaEventListeners.remove(listener);

  /// Inform the OS's background audio system about the playback state; used to
  /// set the progress bar in lockscreen/notification.
  ///
  /// When using background audio, this should be called every time the playback
  /// starts/stops, or there is discontinuity in playback progress (i.e. a seek
  /// or loop restart). It should not be called regularly (i.e. do not call it
  /// every second).
  void setPlaybackState(bool isPlaying, double positionSeconds) async {
    try {
      await audioMethodChannel.invokeMethod<dynamic>(
          setPlaybackStateMethod, <String, dynamic>{
        playbackIsPlayingKey: isPlaying,
        playbackPositionSeconds: positionSeconds
      });
    } on PlatformException catch (e) {
      _logger.severe('setPlaybackState error, category: ', e);
    }
  }

  /// Set the media metadata for display in the OS's background audio system.
  ///
  /// Different OS versions have different behaviors governing when and how
  /// these are displayed. For best results, call this right when the intended
  /// [Audio] starts playback.
  void setMetadata(AudioMetadata metadata) async {
    try {
      final Map<String, dynamic> metadataMap = <String, dynamic>{};
      // Only add non-null values into [metadataMap].
      if (metadata.id != null) {
        metadataMap[metadataIdKey] = metadata.id;
      }
      if (metadata.title != null) {
        metadataMap[metadataTitleKey] = metadata.title;
      }
      if (metadata.album != null) {
        metadataMap[metadataAlbumKey] = metadata.album;
      }
      if (metadata.artist != null) {
        metadataMap[metadataArtistKey] = metadata.artist;
      }
      if (metadata.genre != null) {
        metadataMap[metadataGenreKey] = metadata.genre;
      }
      if (metadata.durationSeconds != null) {
        metadataMap[metadataDurationSecondsKey] = metadata.durationSeconds;
      }
      if (metadata.artBytes != null) {
        metadataMap[metadataArtBytesKey] = metadata.artBytes;
      }

      await audioMethodChannel.invokeMethod<dynamic>(
          setMetadataMethod, metadataMap);
    } on PlatformException catch (e) {
      _logger.severe('setMetadata error, category: ', e);
    }
  }

  /// Set the supported actions in the OS's background audio system.
  ///
  /// Informs device displays and external controllers (e.g. watch/auto) on
  /// what controls to display.
  void setSupportedMediaActions(Set<MediaActionType> actions,
      {double skipIntervalSeconds}) async {
    const Map<MediaActionType, String> mediaActionTypeToString =
        <MediaActionType, String>{
      MediaActionType.playPause: mediaPlayPause,
      MediaActionType.pause: mediaPause,
      MediaActionType.play: mediaPlay,
      MediaActionType.next: mediaNext,
      MediaActionType.previous: mediaPrevious,
      MediaActionType.seekForward: mediaSeekForward,
      MediaActionType.seekBackward: mediaSeekBackward,
      MediaActionType.seekTo: mediaSeekTo,
      MediaActionType.skipForward: mediaSkipForward,
      MediaActionType.skipBackward: mediaSkipBackward,
    };

    final List<String> actionStrings = actions
        .map((MediaActionType type) => mediaActionTypeToString[type])
        .toList();

    final Map<String, dynamic> map = <String, dynamic>{
      mediaActionsKey: actionStrings
    };

    if (skipIntervalSeconds != null) {
      map[mediaSkipIntervalSecondsKey] = skipIntervalSeconds;
    }

    await audioMethodChannel.invokeMethod<dynamic>(
        setSupportedMediaActionsMethod, map);
  }

  /// Specify buttons for display in the Android notification.
  ///
  /// [androidMediaButtons] is a List containing a mix of
  /// [AndroidMediaButtonType] and [AndroidCustomMediaButton].
  ///
  /// [androidCompactIndices] signifies which indices of [androidMediaButtons]
  /// should be shown in the 'compact' notification view. This has a max length
  /// of three.
  ///
  /// Only supported on Android; no-op otherwise.
  void setAndroidNotificationButtons(List<dynamic> androidMediaButtons,
      {List<int> androidCompactIndices}) async {
    const Map<AndroidMediaButtonType, String> androidMediaButtonTypeToString =
        <AndroidMediaButtonType, String>{
      AndroidMediaButtonType.stop: mediaStop,
      AndroidMediaButtonType.pause: mediaPause,
      AndroidMediaButtonType.play: mediaPlay,
      AndroidMediaButtonType.next: mediaNext,
      AndroidMediaButtonType.previous: mediaPrevious,
      AndroidMediaButtonType.seekForward: mediaSeekForward,
      AndroidMediaButtonType.seekBackward: mediaSeekBackward,
    };

    if (!Platform.isAndroid) return;

    try {
      final List<dynamic> androidMediaButtonsData = androidMediaButtons == null
          ? <dynamic>[]
          : androidMediaButtons.map((dynamic buttonTypeOrCustomButton) {
              if (buttonTypeOrCustomButton is AndroidMediaButtonType) {
                final AndroidMediaButtonType buttonType =
                    buttonTypeOrCustomButton;
                return androidMediaButtonTypeToString[buttonType];
              } else if (buttonTypeOrCustomButton is AndroidCustomMediaButton) {
                final AndroidCustomMediaButton customMediaButton =
                    buttonTypeOrCustomButton;
                return <String, String>{
                  mediaCustomTitleKey: customMediaButton.title,
                  mediaCustomEventIdKey: customMediaButton.eventId,
                  mediaCustomDrawableResourceKey:
                      customMediaButton.drawableResource,
                };
              } else {
                _logger.severe(
                    'androidMediaButtons must only contain instances of '
                    'AndroidMediaButtonType or AndroidCustomMediaButton');
                return null;
              }
            }).toList();

      await audioMethodChannel.invokeMethod<dynamic>(
          setAndroidMediaButtonsMethod, <String, dynamic>{
        mediaButtonsKey: androidMediaButtonsData,
        mediaCompactIndicesKey: androidCompactIndices
      });
    } on PlatformException catch (e) {
      _logger.severe('setAndroidMediaButtonsMethod error', e);
    }
  }

  /// Clears the display of the OS's background audio display.
  ///
  /// On Android, this dismisses the notification (and clears all Android
  /// media buttons, metadata, and supported actions). You will need to re-set
  /// those elements, and call [Audio.play()] on a background-enabled
  /// [Audio], to bring back the notification.
  ///
  /// On iOS, this clears the supported controls and metadata from the
  /// lockscreen/control center. However, the lockscreen will continue to
  /// display an empty set of controls with the name of the app. Call
  /// [setMetadata] or [setSupportedMediaActions] to bring back the display.
  ///
  /// Note that any background audio playback will continue. On Android, this
  /// means that audio will continue despite no visible notification from a
  /// foreground Service; this appears to be an undocumented behavior of
  /// Android's MediaBrowserService, in that it keeps the connected Activity
  /// (and its associated Dart process) active.
  void stopBackgroundDisplay() async {
    try {
      await audioMethodChannel
          .invokeMethod<dynamic>(stopBackgroundDisplayMethod);
    } on PlatformException catch (e) {
      _logger.severe('stopBackgroundDisplay error', e);
    }
  }

  /// Sets the iOS audio category.
  ///
  /// Only supported on iOS; no-op otherwise.
  Future<void> setIosAudioCategory(IosAudioCategory category) async {
    const Map<IosAudioCategory, String> categoryToString =
        <IosAudioCategory, String>{
      IosAudioCategory.ambientSolo: iosAudioCategoryAmbientSolo,
      IosAudioCategory.ambientMixed: iosAudioCategoryAmbientMixed,
      IosAudioCategory.playback: iosAudioCategoryPlayback
    };
    if (!Platform.isIOS) return;
    try {
      await audioMethodChannel.invokeMethod<dynamic>(iosAudioCategoryMethod,
          <String, dynamic>{iosAudioCategoryKey: categoryToString[category]});
    } on PlatformException catch (e) {
      _logger.severe('setIosAudioCategory error, category: $category', e);
    }
  }

  /// Handle the [MethodCall]s from the native implementation layer.
  void handleNativeMediaEventCallback(Map<dynamic, dynamic> arguments) {
    const Map<String, MediaActionType> stringToMediaActionType =
        <String, MediaActionType>{
      mediaPause: MediaActionType.pause,
      mediaPlay: MediaActionType.play,
      mediaPlayPause: MediaActionType.playPause,
      mediaStop: MediaActionType.stop,
      mediaNext: MediaActionType.next,
      mediaPrevious: MediaActionType.previous,
      mediaSeekForward: MediaActionType.seekForward,
      mediaSeekBackward: MediaActionType.seekBackward,
      mediaSeekTo: MediaActionType.seekTo,
      mediaSkipForward: MediaActionType.skipForward,
      mediaSkipBackward: MediaActionType.skipBackward,
      mediaCustom: MediaActionType.custom
    };

    final String mediaEventTypeString = arguments[mediaEventTypeKey];
    final MediaActionType type = stringToMediaActionType[mediaEventTypeString];
    if (type == null) {
      _logger
          .severe('Unknown MediaActionType for string $mediaEventTypeString');
      return;
    }
    final MediaEvent event = MediaEvent(type,
        customEventId: arguments[mediaCustomEventIdKey],
        seekToPositionSeconds: arguments[mediaSeekToPositionSecondsKey],
        skipIntervalSeconds: arguments[mediaSkipIntervalSecondsKey]);
    for (final ValueChanged<MediaEvent> mediaEventListener
        in _mediaEventListeners) {
      mediaEventListener(event);
    }
  }
}
