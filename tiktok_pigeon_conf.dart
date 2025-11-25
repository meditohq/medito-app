import 'package:pigeon/pigeon.dart';

// to build the classes: flutter pub run pigeon --input tiktok_pigeon_conf.dart

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/tiktok_pigeon.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/app/src/main/kotlin/meditofoundation/medito/pigeon/TikTokPigeon.g.kt',
    kotlinOptions: KotlinOptions(package: 'meditofoundation.medito.pigeon'),
  ),
)
@HostApi()
abstract class TikTokAndroidApi {
  void initialize(
      String appId, String? tiktokAppId, bool debugMode, String? testEventCode);
  void logEvent(String eventName, Map<String?, Object?>? properties);
}
