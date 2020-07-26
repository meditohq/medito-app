#import <Foundation/Foundation.h>

@class FLTManagedPlayer;

@protocol FLTManagedPlayerDelegate

extern NSTimeInterval const FLTManagedPlayerPlayToEnd;

/**
 * Called by FLTManagedPlayer when a non-looping sound has finished playback,
 * or on calling stop().
 */
- (void)managedPlayerDidFinishPlaying:(NSString *)audioId;

/** Called by FLTManagedPlayer repeatedly while audio is playing. */
- (void)managedPlayerDidUpdatePosition:(NSTimeInterval)position forAudioId:(NSString *)audioId;

/** Called by FLTManagedPlayer when media is loaded and duration is known. */
- (void)managedPlayerDidLoadWithDuration:(NSTimeInterval)duration forAudioId:(NSString *)audioId;

@end

/** Wraps an AVAudioPlayer or AVPlayer for use by AudiofileplayerPlugin. */
@interface FLTManagedPlayer : NSObject

@property(nonatomic, readonly) NSString *audioId;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithAudioId:(NSString *)audioId
                           path:(NSString *)path
                       delegate:(id<FLTManagedPlayerDelegate>)delegate
                      isLooping:(bool)isLooping;

- (instancetype)initWithAudioId:(NSString *)audioId
                           data:(NSData *)data
                       delegate:(id<FLTManagedPlayerDelegate>)delegate
                      isLooping:(bool)isLooping;

- (instancetype)initWithAudioId:(NSString *)audioId
                      remoteUrl:(NSString *)urlString
                       delegate:(id<FLTManagedPlayerDelegate>)delegate
                      isLooping:(bool)isLooping
              remoteLoadHandler:(void (^)(BOOL))remoteLoadHandler;
/**
 * Plays the audio data.
 *
 * @param endpoint the time, as an NSTimeInterval, to play to. To play until
 * the end, pass FLTManagedPlayerPlayToEnd.
 */
- (void)play:(bool)playFromStart endpoint:(NSTimeInterval)endpoint;
- (void)releasePlayer;
- (void)seek:(NSTimeInterval)position completionHandler:(void (^)())completionHandler;
- (void)setVolume:(double)volume;
- (void)pause;

@end
