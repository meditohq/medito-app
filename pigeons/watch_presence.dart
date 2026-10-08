import 'package:pigeon/pigeon.dart';

// to build the classes: flutter pub run pigeon --input pigeons/watch_presence.dart

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/watch_presence_pigeon.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/app/src/main/kotlin/meditofoundation/medito/pigeon/WatchPresencePigeon.g.kt',
    // Own error class names so further Pigeon files don't collide (AudioPigeon.g.kt
    // already defines FlutterError in this package).
    kotlinOptions: KotlinOptions(
      package: 'meditofoundation.medito.pigeon',
      errorClassName: 'WatchPresenceFlutterError',
    ),
    swiftOut: 'ios/Runner/WatchPresencePigeon.g.swift',
    swiftOptions: SwiftOptions(errorClassName: 'WatchPresencePigeonError'),
  ),
)
//ignore:prefer-match-file-name
class WatchStatus {
  WatchStatus({required this.paired, required this.appInstalled});

  /// A watch is set up with this phone (Apple Watch paired / Wear OS
  /// companion app installed).
  bool paired;

  /// The Medito watch app is installed on that watch.
  bool appInstalled;
}

/// Watch presence for analytics and the Settings install prompt. Native side:
/// WatchPresence in AppDelegate.swift (WCSession) and WatchPresence.kt (Data
/// Layer nodes / capability, companion apps as a fallback).
@HostApi()
abstract class WatchPresenceApi {
  /// Fails (instead of reporting no watch) when the state can't be read, e.g.
  /// WCSession didn't activate.
  @async
  WatchStatus getStatus();

  /// Starts installing the Medito watch app. Android opens Medito's Play
  /// Store page on each connected watch that lacks it; iOS opens the Watch
  /// app (there is no API to install from the phone). Returns false when
  /// nothing could be opened.
  @async
  bool openWatchInstall();
}
