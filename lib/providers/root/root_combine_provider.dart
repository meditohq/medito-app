import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../constants/strings/route_constants.dart';

final rootCombineProvider = Provider.family<void, BuildContext>(
  (ref, context) {
    ref.read(remoteStatsProvider);
    ref.read(authProvider.notifier).saveFcmTokenEvent();
    ref.read(postLocalStatsProvider);
    ref.read(deviceAppAndUserInfoProvider);
    ref.read(audioDownloaderProvider).deleteDownloadedFileFromPreviousVersion();

    checkMaintenance(ref, context);
  },
);

void _handleAudioCompletion(Ref ref, BuildContext context) {
  final audioProvider = ref.read(audioPlayerNotifierProvider);
  final bgSoundProvider = ref.read(backgroundSoundsNotifierProvider);
  var extras = audioProvider.mediaItem.value?.extras;
  if (extras != null) {
    ref.read(playerProvider.notifier).handleAudioCompletionEvent(
      extras[TypeConstants.trackIdKey],
    );
  }
}

void checkMaintenance(ProviderRef<void> ref, BuildContext context) {
    ref.read(fetchMaintenanceProvider.future).then(
    (maintenanceData) {
      ref.read(deviceAndAppInfoProvider.future).then(
        (deviceInfo) {
          var buildNumber = int.parse(deviceInfo.buildNumber);
          if (maintenanceData.isUnderMaintenance || (maintenanceData.minimumBuildNumber ?? 0) > buildNumber) {
            context.push(
              RouteConstants.maintenancePath,
              extra: maintenanceData,
            );
          }
        },
      );
    },
  );
}
