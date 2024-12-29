import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:medito/models/path/path_result.dart';
import 'package:medito/providers/providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/types/type_constants.dart';
import '../../utils/stats_updater.dart';
import '../../views/maintenance/maintenance_view.dart';
import '../maintenance/maintenance_provider.dart';
import '../../controllers/path_notifier.dart';

final rootCombineProvider = Provider.family<void, BuildContext>(
  (ref, context) {
    checkMaintenance(ref, context);

    if (Platform.isIOS) {
      var streamEvent = iosAudioHandler.iosStateStream
          .map((event) => event.playerState.processingState)
          .distinct();
      streamEvent.forEach((element) async {
        if (element == ProcessingState.completed) {
          var userToken = await getUserToken();
          var mediaItem = iosAudioHandler.mediaItem.value;
          var trackId = iosAudioHandler.trackState.id;
          var payload = {
            TypeConstants.trackIdKey: trackId,
            TypeConstants.durationIdKey:
                iosAudioHandler.duration?.inMilliseconds ?? 0,
            TypeConstants.fileIdKey: mediaItem?.title ?? '',
            TypeConstants.guideIdKey: iosAudioHandler.trackState.artist ?? '',
            TypeConstants.timestampIdKey: DateTime.now().millisecondsSinceEpoch,
            UpdateStatsConstants.userTokenKey: userToken,
          };

          await handleStats(payload);

          // Update path task completion if this track is part of a path
          await _updatePathTaskIfNeeded(ref, trackId);
        }
      });
    }
  },
);

Future<String?> getUserToken() async {
  var supabase = Supabase.instance.client;
  var user = supabase.auth.currentUser;
  return user?.userMetadata?['userToken'] as String?;
}

void checkMaintenance(Ref<void> ref, BuildContext context) {
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

Future<void> _updatePathTaskIfNeeded(Ref ref, String trackId) async {
  final pathState = ref.read(pathNotifierProvider);

  if (pathState is AsyncData<List<JourneyStep>>) {
    for (final step in pathState.value) {
      for (final task in step.tasks) {
        final taskData = task.data;
        if (task.type == TaskType.track && taskData.id == trackId) {
          await ref
              .read(pathNotifierProvider.notifier)
              .updateTaskCompletion(task.id, true);
          break;
        }
      }
    }
  }
}
