#import "AudiofileplayerPlugin.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import "ManagedPlayer.h"

static NSString *const kChannel = @"audiofileplayer";
static NSString *const kLoadMethod = @"load";
static NSString *const kFlutterPath = @"flutterPath";
static NSString *const kAbsolutePath = @"absolutePath";
static NSString *const kAudioBytes = @"audioBytes";
static NSString *const kRemoteUrl = @"remoteUrl";
static NSString *const kAudioId = @"audioId";
static NSString *const kLooping = @"looping";
static NSString *const kReleaseMethod = @"release";
static NSString *const kPlayMethod = @"play";
static NSString *const kPlayFromStart = @"playFromStart";
static NSString *const kEndpointSeconds = @"endpointSeconds";
static NSString *const kSeekMethod = @"seek";
static NSString *const kSetVolumeMethod = @"setVolume";
static NSString *const kVolume = @"volume";
static NSString *const kPauseMethod = @"pause";
static NSString *const kOnCompleteCallback = @"onComplete";
static NSString *const kOnDurationCallback = @"onDuration";
static NSString *const kDurationSeconds = @"duration_seconds";
static NSString *const kOnPositionCallback = @"onPosition";
static NSString *const kPositionSeconds = @"position_seconds";
static NSString *const kStopBackgroundDisplay = @"stopBackgroundDisplay";
static NSString *const kErrorCode = @"AudioPluginError";

static NSString *const kAudioCategoryMethod = @"iosAudioCategory";
static NSString *const kAudioCategory = @"iosAudioCategory";
static NSString *const kAudioCategoryAmbientSolo = @"iosAudioCategoryAmbientSolo";
static NSString *const kAudioCategoryAmbientMixed = @"iosAudioCategoryAmbientMixed";
static NSString *const kAudioCategoryPlayback = @"iosAudioCategoryPlayback";

//
static NSString *const kSetPlaybackStateMethod = @"setPlaybackState";
static NSString *const kPlaybackIsPlaying = @"playbackIsPlaying";
static NSString *const kPlaybackPositionSeconds = @"playbackPositionSeconds";

//
static NSString *const kSetMetadataMethod = @"setMetadata";
static NSString *const kMetadataId = @"metadataId";
static NSString *const kMetadataTitle = @"metadataTitle";
static NSString *const kMetadataAlbum = @"metadataAlbum";
static NSString *const kMetadataArtist = @"metadataArtist";
static NSString *const kMetadataGenre = @"metadataGenre";
static NSString *const kMetadataDurationSeconds = @"metadataDurationSeconds";
static NSString *const kMetadataArtBytes = @"metadataArtBytes";

//
static NSString *const kSetSupportedMediaActionsMethod = @"setSupportedMediaActions";
static NSString *const kMediaActions = @"mediaActions";
static NSString *const kOnMediaEventCallback = @"onMediaEvent";
static NSString *const kMediaEventType = @"mediaEventType";
static NSString *const kMediaStop = @"stop";
static NSString *const kMediaPause = @"pause";
static NSString *const kMediaPlay = @"play";
static NSString *const kMediaPlayPause = @"playPause";
static NSString *const kMediaNext = @"next";
static NSString *const kMediaPrevious = @"previous";
static NSString *const kMediaSeekForward = @"seekForward";
static NSString *const kMediaSeekBackward = @"seekBackward";
static NSString *const kMediaSeekTo = @"seekTo";
static NSString *const kMediaSeekToPositionSeconds = @"seekToPositionSeconds";
static NSString *const kMediaSkipForward = @"skipForward";
static NSString *const kMediaSkipBackward = @"skipBackward";
static NSString *const kMediaSkipIntervalSeconds = @"skipIntervalSeconds";

@interface AudiofileplayerPlugin ()<FLTManagedPlayerDelegate>
@end

@implementation AudiofileplayerPlugin {
  NSObject<FlutterPluginRegistrar> *_registrar;
  FlutterMethodChannel *_channel;
  NSMutableDictionary<NSString *, FLTManagedPlayer *> *_playersDict;
  NSMutableDictionary *_nowPlayingInfo;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  FlutterMethodChannel *channel =
      [FlutterMethodChannel methodChannelWithName:kChannel binaryMessenger:[registrar messenger]];
  AudiofileplayerPlugin *instance =
      [[AudiofileplayerPlugin alloc] initWithRegistrar:registrar channel:channel];
  [registrar addMethodCallDelegate:instance channel:channel];
  [registrar addApplicationDelegate:instance];
}

- (instancetype)initWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar
                          channel:(FlutterMethodChannel *)channel {
  self = [super init];
  if (self) {
    _registrar = registrar;
    _channel = channel;
    _playersDict = [NSMutableDictionary dictionary];
    _nowPlayingInfo = [NSMutableDictionary dictionary];
    [self addCommandHandlers];
    [self disableCommandHandlers];
    // Set audio category to initial default of 'playback'.
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
  }
  return self;
}

- (void)dealloc {
  [self removeCommandHandlers];
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  NSLog(@"handleMethodCall: method = %@", call.method);

  if ([call.method isEqualToString:kLoadMethod]) {
    // Loading an audio instance.
    [self handleLoadWithCall:call result:result];
    return;
  } else if ([call.method isEqualToString:kAudioCategoryMethod]) {
    // Setting the audio category.
    NSString *categoryString = call.arguments[kAudioCategory];
    AVAudioSessionCategory category;
    if ([categoryString isEqualToString:kAudioCategoryAmbientSolo]) {
      category = AVAudioSessionCategorySoloAmbient;
    } else if ([categoryString isEqualToString:kAudioCategoryAmbientMixed]) {
      category = AVAudioSessionCategoryAmbient;
    }
    if ([categoryString isEqualToString:kAudioCategoryPlayback]) {
      category = AVAudioSessionCategoryPlayback;
    }
    [[AVAudioSession sharedInstance] setCategory:category error:nil];
    result(nil);
    return;
  } else if ([call.method isEqualToString:kSetPlaybackStateMethod]) {
    [self updateNowPlayingInfoFromPlaybackState:call.arguments];
    result(nil);
    return;
  } else if ([call.method isEqualToString:kSetMetadataMethod]) {
    [self updateNowPlayingInfoFromMetadata:call.arguments];
    result(nil);
    return;
  } else if ([call.method isEqualToString:kSetSupportedMediaActionsMethod]) {
    NSArray<NSString *> *mediaActionTypes = call.arguments[kMediaActions];
    NSNumber *skipIntervalNumber = call.arguments[kMediaSkipIntervalSeconds];
    [self enableCommandHandlersFromMediaActionTypes:mediaActionTypes
                                       skipInterval:skipIntervalNumber];
    result(nil);
    return;
  } else if ([call.method isEqualToString:kStopBackgroundDisplay]) {
    // Clear now playing info and all command handlers.
    [_nowPlayingInfo removeAllObjects];
    MPNowPlayingInfoCenter.defaultCenter.nowPlayingInfo = _nowPlayingInfo;
    [self disableCommandHandlers];
    result(nil);
    return;
  }

  // All subsequent calls need a valid player.
  NSString *audioId = call.arguments[@"audioId"];
  if (!audioId) {
    result([FlutterError
        errorWithCode:kErrorCode
              message:[NSString
                          stringWithFormat:@"Received %@ call without an audioId", call.method]
              details:nil]);
    return;
  }
  FLTManagedPlayer *player = _playersDict[audioId];
  if (!player) {
    result([FlutterError
        errorWithCode:kErrorCode
              message:[NSString stringWithFormat:@"Called %@ on an unloaded player: %@",
                                                 call.method, audioId]
              details:nil]);
    return;
  }

  if ([call.method isEqualToString:kPlayMethod]) {
    bool playFromStart = [call.arguments[kPlayFromStart] boolValue];
    NSNumber *endpointSecondsNumber = call.arguments[kEndpointSeconds];
    NSTimeInterval endpoint =
        endpointSecondsNumber ? [endpointSecondsNumber doubleValue] : FLTManagedPlayerPlayToEnd;
    [player play:playFromStart endpoint:endpoint];
    result(nil);
  } else if ([call.method isEqualToString:kReleaseMethod]) {
    [player releasePlayer];
    [_playersDict removeObjectForKey:audioId];
    result(nil);
  } else if ([call.method isEqualToString:kSeekMethod]) {
    NSTimeInterval position = [call.arguments[kPositionSeconds] doubleValue];
    [player seek:position
        completionHandler:^() {
          result(nil);
        }];
  } else if ([call.method isEqualToString:kSetVolumeMethod]) {
    double volume = [call.arguments[kVolume] doubleValue];
    [player setVolume:volume];
    result(nil);
  } else if ([call.method isEqualToString:kPauseMethod]) {
    [player pause];
    result(nil);
  } else {
    result(FlutterMethodNotImplemented);
  }
}

- (void)handleLoadWithCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  NSString *audioId = call.arguments[kAudioId];
  if (!audioId) {
    result([FlutterError errorWithCode:kErrorCode
                               message:@"Received load call without an audioId"
                               details:nil]);
    return;
  }
  if (_playersDict[audioId]) {
    result([FlutterError
        errorWithCode:kErrorCode
              message:[NSString
                          stringWithFormat:@"Tried to load an already-loaded player: %@", audioId]
              details:nil]);
    return;
  }

  bool isLooping = [call.arguments[kLooping] boolValue];

  FLTManagedPlayer *player = nil;
  if (call.arguments[kFlutterPath] != [NSNull null]) {
    NSString *flutterPath = call.arguments[kFlutterPath];
    NSString *key = [_registrar lookupKeyForAsset:flutterPath];
    NSString *path = [[NSBundle mainBundle] pathForResource:key ofType:nil];
    if (!path) {
      result([FlutterError
          errorWithCode:kErrorCode
                message:[NSString stringWithFormat:
                                      @"Could not get path for flutter asset %@ for audio %@ ",
                                      flutterPath, audioId]
                details:nil]);
      return;
    }
    player = [[FLTManagedPlayer alloc] initWithAudioId:audioId
                                                  path:path
                                              delegate:self
                                             isLooping:isLooping];
    _playersDict[audioId] = player;
    result(nil);
  } else if (call.arguments[kAbsolutePath] != [NSNull null]) {
    NSString *absolutePath = call.arguments[kAbsolutePath];
    player = [[FLTManagedPlayer alloc] initWithAudioId:audioId
                                                  path:absolutePath
                                              delegate:self
                                             isLooping:isLooping];
    if (!player) {
      result([FlutterError
          errorWithCode:kErrorCode
                message:[NSString
                            stringWithFormat:@"Could not load from absolute path %@ for audio %@ ",
                                             absolutePath, audioId]
                details:nil]);
      return;
    }
    _playersDict[audioId] = player;
    result(nil);
  } else if (call.arguments[kAudioBytes] != [NSNull null]) {
    FlutterStandardTypedData *flutterData = call.arguments[kAudioBytes];
    player = [[FLTManagedPlayer alloc] initWithAudioId:audioId
                                                  data:[flutterData data]
                                              delegate:self
                                             isLooping:isLooping];
    if (!player) {
      result([FlutterError
          errorWithCode:kErrorCode
                message:[NSString stringWithFormat:@"Could not load from audio bytes for audio %@ ",
                                                   audioId]
                details:nil]);
      return;
    }
    _playersDict[audioId] = player;
    result(nil);
  } else if (call.arguments[kRemoteUrl] != [NSNull null]) {
    NSString *urlString = call.arguments[kRemoteUrl];
    // Load player, but wait for remote loading to succeed/fail before returning the methodCall.
    __weak AudiofileplayerPlugin *weakSelf = self;
    player = [[FLTManagedPlayer alloc]
          initWithAudioId:audioId
                remoteUrl:urlString
                 delegate:self
                isLooping:isLooping
        remoteLoadHandler:^(BOOL success) {
          if (success) {
            result(nil);
          } else {
            AudiofileplayerPlugin *strongSelf = weakSelf;
            if (strongSelf) {
              [strongSelf->_playersDict removeObjectForKey:audioId];
            }
            result([FlutterError
                errorWithCode:kErrorCode
                      message:[NSString
                                  stringWithFormat:@"Could not load remote URL %@ for player %@",
                                                   urlString, audioId]
                      details:nil]);
          }
        }];
    // Put AVPlayer into dictionary syncl'y on creation. Will be removed in the remoteLoadHandler
    // if remote loading fails.
    _playersDict[audioId] = player;
  } else {
    result([FlutterError errorWithCode:kErrorCode
                               message:@"Could not create ManagedMediaPlayer with neither "
                                       @"flutterPath nor absolutePath nor audioBytes nor remoteUrl"
                               details:nil]);
  }
}

#pragma mark - FLTManagedPlayerDelegate

- (void)managedPlayerDidFinishPlaying:(NSString *)audioId {
  [_channel invokeMethod:kOnCompleteCallback arguments:@{kAudioId : audioId}];
}

- (void)managedPlayerDidUpdatePosition:(NSTimeInterval)position forAudioId:(NSString *)audioId {
  [_channel invokeMethod:kOnPositionCallback
               arguments:@{
                 kAudioId : audioId,
                 kPositionSeconds : @(position),
               }];
}

- (void)managedPlayerDidLoadWithDuration:(NSTimeInterval)duration forAudioId:(NSString *)audioId {
  [_channel invokeMethod:kOnDurationCallback
               arguments:@{
                 kAudioId : audioId,
                 kDurationSeconds : @(duration),
               }];
}

#pragma mark - MPRemoteCommandCenter targets

- (void)addCommandHandlers {
  MPRemoteCommandCenter *remoteCommandCenter = [MPRemoteCommandCenter sharedCommandCenter];
  [remoteCommandCenter.togglePlayPauseCommand addTarget:self
                                                 action:@selector(handleTogglePlayPauseCommand:)];
  [remoteCommandCenter.playCommand addTarget:self action:@selector(handlePlayCommand:)];
  [remoteCommandCenter.pauseCommand addTarget:self action:@selector(handlePauseCommand:)];
  [remoteCommandCenter.nextTrackCommand addTarget:self action:@selector(handleNextTrackCommand:)];
  [remoteCommandCenter.previousTrackCommand addTarget:self
                                               action:@selector(handlePreviousTrackCommand:)];
  [remoteCommandCenter.seekForwardCommand addTarget:self
                                             action:@selector(handleSeekForwardCommand:)];
  [remoteCommandCenter.seekBackwardCommand addTarget:self
                                              action:@selector(handleSeekBackwardCommand:)];
  [remoteCommandCenter.changePlaybackPositionCommand
      addTarget:self
         action:@selector(handleChangePlaybackPositionCommand:)];
  [remoteCommandCenter.skipForwardCommand addTarget:self
                                             action:@selector(handleSkipForwardCommand:)];
  [remoteCommandCenter.skipBackwardCommand addTarget:self
                                              action:@selector(handleSkipBackwardCommand:)];
}

- (void)disableCommandHandlers {
  MPRemoteCommandCenter *remoteCommandCenter = [MPRemoteCommandCenter sharedCommandCenter];
  remoteCommandCenter.togglePlayPauseCommand.enabled = NO;
  remoteCommandCenter.playCommand.enabled = NO;
  remoteCommandCenter.pauseCommand.enabled = NO;
  remoteCommandCenter.nextTrackCommand.enabled = NO;
  remoteCommandCenter.previousTrackCommand.enabled = NO;
  remoteCommandCenter.seekForwardCommand.enabled = NO;
  remoteCommandCenter.seekBackwardCommand.enabled = NO;
  remoteCommandCenter.changePlaybackPositionCommand.enabled = NO;
  remoteCommandCenter.skipForwardCommand.enabled = NO;
  remoteCommandCenter.skipBackwardCommand.enabled = NO;
}

- (void)removeCommandHandlers {
  MPRemoteCommandCenter *remoteCommandCenter = [MPRemoteCommandCenter sharedCommandCenter];
  [remoteCommandCenter.togglePlayPauseCommand removeTarget:self];
  [remoteCommandCenter.playCommand removeTarget:self];
  [remoteCommandCenter.pauseCommand removeTarget:self];
  [remoteCommandCenter.nextTrackCommand removeTarget:self];
  [remoteCommandCenter.previousTrackCommand removeTarget:self];
  [remoteCommandCenter.seekForwardCommand removeTarget:self];
  [remoteCommandCenter.seekBackwardCommand removeTarget:self];
  [remoteCommandCenter.changePlaybackPositionCommand removeTarget:self];
  [remoteCommandCenter.skipForwardCommand removeTarget:self];
  [remoteCommandCenter.skipBackwardCommand removeTarget:self];
}

- (void)enableCommandHandlersFromMediaActionTypes:(NSArray<NSString *> *)mediaActionTypes
                                     skipInterval:(NSNumber *)skipIntervalNumber {
  NSLog(@"mediaActionTypes: %@", mediaActionTypes);
  MPRemoteCommandCenter *remoteCommandCenter = [MPRemoteCommandCenter sharedCommandCenter];
  remoteCommandCenter.togglePlayPauseCommand.enabled =
      [mediaActionTypes containsObject:kMediaPlayPause];
  remoteCommandCenter.playCommand.enabled = [mediaActionTypes containsObject:kMediaPlay];
  remoteCommandCenter.pauseCommand.enabled = [mediaActionTypes containsObject:kMediaPause];
  remoteCommandCenter.nextTrackCommand.enabled = [mediaActionTypes containsObject:kMediaNext];
  remoteCommandCenter.previousTrackCommand.enabled =
      [mediaActionTypes containsObject:kMediaPrevious];
  remoteCommandCenter.seekForwardCommand.enabled =
      [mediaActionTypes containsObject:kMediaSeekForward];
  remoteCommandCenter.seekBackwardCommand.enabled =
      [mediaActionTypes containsObject:kMediaSeekBackward];
  remoteCommandCenter.changePlaybackPositionCommand.enabled =
      [mediaActionTypes containsObject:kMediaSeekTo];
  remoteCommandCenter.skipForwardCommand.enabled =
      [mediaActionTypes containsObject:kMediaSkipForward];
  remoteCommandCenter.skipBackwardCommand.enabled =
      [mediaActionTypes containsObject:kMediaSkipBackward];
  if (skipIntervalNumber) {
    remoteCommandCenter.skipForwardCommand.preferredIntervals = @[ skipIntervalNumber ];
    remoteCommandCenter.skipBackwardCommand.preferredIntervals = @[ skipIntervalNumber ];
  }
}

- (MPRemoteCommandHandlerStatus)handleTogglePlayPauseCommand:
    (MPRemoteCommandEvent *)remoteCommandEvent {
  [_channel invokeMethod:kOnMediaEventCallback arguments:@{kMediaEventType : kMediaPlayPause}];
  return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)handlePlayCommand:(MPRemoteCommandEvent *)remoteCommandEvent {
  [_channel invokeMethod:kOnMediaEventCallback arguments:@{kMediaEventType : kMediaPlay}];
  return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)handlePauseCommand:(MPRemoteCommandEvent *)remoteCommandEvent {
  [_channel invokeMethod:kOnMediaEventCallback arguments:@{kMediaEventType : kMediaPause}];
  return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)handleNextTrackCommand:(MPRemoteCommandEvent *)remoteCommandEvent {
  [_channel invokeMethod:kOnMediaEventCallback arguments:@{kMediaEventType : kMediaNext}];
  return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)handlePreviousTrackCommand:
    (MPRemoteCommandEvent *)remoteCommandEvent {
  [_channel invokeMethod:kOnMediaEventCallback arguments:@{kMediaEventType : kMediaPrevious}];
  return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)handleSeekForwardCommand:
    (MPRemoteCommandEvent *)remoteCommandEvent {
  [_channel invokeMethod:kOnMediaEventCallback arguments:@{kMediaEventType : kMediaSeekForward}];
  return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)handleSeekBackwardCommand:
    (MPRemoteCommandEvent *)remoteCommandEvent {
  [_channel invokeMethod:kOnMediaEventCallback arguments:@{kMediaEventType : kMediaSeekBackward}];
  return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)handleChangePlaybackPositionCommand:
    (MPChangePlaybackPositionCommandEvent *)changePlaybackPositionCommandEvent {
  NSTimeInterval positionSeconds = changePlaybackPositionCommandEvent.positionTime;
  [_channel invokeMethod:kOnMediaEventCallback
               arguments:@{
                 kMediaEventType : kMediaSeekTo,
                 kMediaSeekToPositionSeconds : @(positionSeconds)
               }];
  return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)handleSkipForwardCommand:
    (MPSkipIntervalCommandEvent *)skipIntervalCommandEvent {
  [_channel invokeMethod:kOnMediaEventCallback
               arguments:@{
                 kMediaEventType : kMediaSkipForward,
                 kMediaSkipIntervalSeconds : @(skipIntervalCommandEvent.interval)
               }];
  return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)handleSkipBackwardCommand:
    (MPRemoteCommandEvent *)remoteCommandEvent {
  [_channel invokeMethod:kOnMediaEventCallback arguments:@{kMediaEventType : kMediaSkipBackward}];
  return MPRemoteCommandHandlerStatusSuccess;
}

#pragma mark - MPNowPlayingInfoCenter

- (void)updateNowPlayingInfoFromPlaybackState:(NSDictionary *)playbackState {
  bool isPlaying = [playbackState[kPlaybackIsPlaying] boolValue];
  _nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? @(1.0) : @(0.0);
  _nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] =
      playbackState[kPlaybackPositionSeconds];

  MPNowPlayingInfoCenter.defaultCenter.nowPlayingInfo = _nowPlayingInfo;
}

- (void)updateNowPlayingInfoFromMetadata:(NSDictionary *)metadata {
  _nowPlayingInfo[MPMediaItemPropertyPersistentID] = metadata[kMetadataId];
  _nowPlayingInfo[MPMediaItemPropertyTitle] = metadata[kMetadataTitle];
  _nowPlayingInfo[MPMediaItemPropertyArtist] = metadata[kMetadataArtist];
  _nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = metadata[kMetadataAlbum];
  _nowPlayingInfo[MPMediaItemPropertyGenre] = metadata[kMetadataGenre];
  _nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = metadata[kMetadataDurationSeconds];

  if (metadata[kMetadataArtBytes]) {
    FlutterStandardTypedData *flutterData = metadata[kMetadataArtBytes];
    NSData *data = [flutterData data];
    UIImage *image = [UIImage imageWithData:data];
    _nowPlayingInfo[MPMediaItemPropertyArtwork] =
        [[MPMediaItemArtwork alloc] initWithBoundsSize:CGSizeMake(200.0, 200.0)
                                        requestHandler:^UIImage *(CGSize size) {
                                          return image;
                                        }];
  } else {
    _nowPlayingInfo[MPMediaItemPropertyArtwork] = nil;
  }

  MPNowPlayingInfoCenter.defaultCenter.nowPlayingInfo = _nowPlayingInfo;
}

@end
