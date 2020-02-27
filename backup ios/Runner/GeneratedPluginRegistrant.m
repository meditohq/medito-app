//
//  Generated file. Do not edit.
//

#import "GeneratedPluginRegistrant.h"

#if __has_include(<audioplayers/AudioplayersPlugin.h>)
#import <audioplayers/AudioplayersPlugin.h>
#else
@import audioplayers;
#endif

#if __has_include(<flutter_matomo/FlutterMatomoPlugin.h>)
#import <flutter_matomo/FlutterMatomoPlugin.h>
#else
@import flutter_matomo;
#endif

#if __has_include(<path_provider/FLTPathProviderPlugin.h>)
#import <path_provider/FLTPathProviderPlugin.h>
#else
@import path_provider;
#endif

@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [AudioplayersPlugin registerWithRegistrar:[registry registrarForPlugin:@"AudioplayersPlugin"]];
  [FlutterMatomoPlugin registerWithRegistrar:[registry registrarForPlugin:@"FlutterMatomoPlugin"]];
  [FLTPathProviderPlugin registerWithRegistrar:[registry registrarForPlugin:@"FLTPathProviderPlugin"]];
}

@end
