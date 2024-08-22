import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/strings/shared_preference_constants.dart';
import '../../constants/types/type_constants.dart';
import '../../models/user/user_token_model.dart';
import '../../utils/call_update_stats.dart';
import '../../utils/stats_updater.dart';
import '../../views/maintenance/maintenance_view.dart';
import '../maintenance/maintenance_provider.dart';

final rootCombineProvider = Provider.family<void, BuildContext>(
  (ref, context) {
    ref.read(fetchStatsProvider);
    ref.read(deviceAppAndUserInfoProvider);
    checkMaintenance(ref, context);

    if (Platform.isIOS) {
      var streamEvent = iosAudioHandler.iosStateStream
          .map((event) => event.playerState.processingState)
          .distinct();
      streamEvent.forEach((element) {
        getUserToken().then(
          (userToken) async {
            if (element == ProcessingState.completed) {
              var mediaItem = iosAudioHandler.mediaItem.value;
              var payload = {
                TypeConstants.trackIdKey: iosAudioHandler.trackState.id,
                TypeConstants.durationIdKey:
                    iosAudioHandler.duration?.inMilliseconds ?? 0,
                TypeConstants.fileIdKey: mediaItem?.title ?? '',
                TypeConstants.guideIdKey:
                    iosAudioHandler.trackState.artist ?? '',
                TypeConstants.timestampIdKey:
                    DateTime.now().millisecondsSinceEpoch,
                UpdateStatsConstants.userTokenKey: userToken,
              };
              await handleStats(payload);
            }
          },
        );
      });
    }
  },
);
// } else {
//   ref.listen(audioStateProvider, (previous, current) {
//     if (current.isCompleted) {
//       var payload = {
//         TypeConstants.trackIdKey: current.track.id,
//         TypeConstants.durationIdKey: current.duration,
//         TypeConstants.fileIdKey: current.track.title,
//         TypeConstants.guideIdKey: current.track.artist,
//         TypeConstants.timestampIdKey: DateTime.now().millisecondsSinceEpoch,
//         UpdateStatsConstants.userTokenKey: getUserToken(),
//       };
//
//       unawaited(handleStats(payload).then((success) {
//         if (success) {
//           ref.invalidate(fetchStatsProvider);
//           ref
//               .read(playerProvider.notifier)
//               .cancelPendingNotificationsForAudioCompleteEvent();
//         }
//       }));
//     }
//   });
// }

Future<String?> getUserToken() async {
  final prefs = await SharedPreferences.getInstance();
  final userJson = prefs.getString(SharedPreferenceConstants.userToken);

  if (userJson == null) {
    return null;
  }

  final userModel = UserTokenModel.fromJson(json.decode(userJson));

  return userModel.token;
}

void checkMaintenance(ProviderRef<void> ref, BuildContext context) {
  ref.read(fetchMaintenanceProvider.future).then(
    (maintenanceData) {
      ref.read(deviceAndAppInfoProvider.future).then(
        (deviceInfo) {
          var buildNumber = int.parse(deviceInfo.buildNumber);
          if (maintenanceData.isUnderMaintenance ||
              (maintenanceData.minimumBuildNumber ?? 0) > buildNumber) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MaintenanceView(
                  maintenanceModel: maintenanceData,
                ),
              ),
            );
          }
        },
      );
    },
  );
}
