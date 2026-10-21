import 'package:pigeon/pigeon.dart';

// to build the classes: flutter pub run pigeon --input pigeons/download_all.dart

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/download_all_pigeon.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/app/src/main/kotlin/meditofoundation/medito/pigeon/DownloadAllPigeon.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'meditofoundation.medito.pigeon',
      errorClassName: 'DownloadAllFlutterError',
    ),
    swiftOut: 'ios/Runner/DownloadAllPigeon.g.swift',
    swiftOptions: SwiftOptions(errorClassName: 'DownloadAllPigeonError'),
  ),
)
//ignore:prefer-match-file-name
class BatchStatus {
  BatchStatus({
    required this.isRunning,
    required this.completed,
    required this.total,
    required this.failed,
  });

  bool isRunning;
  int completed;
  int total;
  int failed;
}

@HostApi()
abstract class DownloadAllHostApi {
  void startBatch(String manifestJsonPath);
  void stopBatch();
  BatchStatus getStatus();
}
