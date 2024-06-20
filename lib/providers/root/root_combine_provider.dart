import 'dart:convert';
import 'dart:io';

import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../constants/strings/shared_preference_constants.dart';
import '../../constants/types/type_constants.dart';
import '../../models/user/user_token_model.dart';
import '../../services/notifications/notifications_service.dart';
import '../../utils/call_update_stats.dart';
import '../../views/maintenance/maintenance_view.dart';
import '../maintenance/maintenance_provider.dart';

final rootCombineProvider = Provider.family<void, BuildContext>(
  (ref, context) {
    ref.read(refreshStatsProvider);
    ref.read(deviceAppAndUserInfoProvider);
    checkMaintenance(ref, context);

    if (Platform.isIOS) {
      var streamEvent = iosAudioHandler.iosStateStream
          .map((event) => event.playerState.processingState)
          .distinct();
      streamEvent.forEach((element) {
        if (element == ProcessingState.completed) {
          var mediaItem = iosAudioHandler.mediaItem.value;
          var payload = {
            TypeConstants.trackIdKey: iosAudioHandler.trackState.id,
            TypeConstants.durationIdKey:
                iosAudioHandler.duration?.inMilliseconds ?? 0,
            TypeConstants.fileIdKey: mediaItem?.title ?? '',
            TypeConstants.guideIdKey: iosAudioHandler.trackState.artist ?? '',
            TypeConstants.timestampIdKey: DateTime.now().millisecondsSinceEpoch,
            UpdateStatsConstants.userTokenKey: getUserToken(ref),
          };
          handleStats(payload);
        }
      });
    }
  },
);

String? getUserToken(Ref ref) {
  var user = ref
      .read(sharedPreferencesProvider)
      .getString(SharedPreferenceConstants.userToken);
  var userModel =
      user != null ? UserTokenModel.fromJson(json.decode(user)) : null;
  if (userModel != null) {
    return userModel.token;
  }

  return null;
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
