// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/maintenance/maintenance_model.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/utils/stats_updater.dart';
import '../maintenance/maintenance_provider.dart';

/// Provides the maintenance model if maintenance is needed, null otherwise
final maintenanceNeededProvider =
    FutureProvider<MaintenanceModel?>((ref) async {
  try {
    AppLogger.d('ROOT', '[MAINTENANCE] Starting maintenance check');
    final maintenanceData = await ref.read(fetchMaintenanceProvider.future);

    final deviceInfo = await ref.read(deviceAndAppInfoProvider.future);

    final buildNumber = int.tryParse(deviceInfo.buildNumber) ?? 0;
    final minRequired = maintenanceData.minimumBuildNumber ?? 0;

    final needsMaintenance = (maintenanceData.isUnderMaintenance) ||
        minRequired > buildNumber;

    debugPrint(
        '[MAINTENANCE] Current build: $buildNumber, Minimum required: $minRequired, Under maintenance: ${maintenanceData.isUnderMaintenance}');
    AppLogger.d('ROOT', '[MAINTENANCE] Needs maintenance: $needsMaintenance');

    if (needsMaintenance) {
      AppLogger.d('ROOT', '[MAINTENANCE] Maintenance needed, returning model');
      return maintenanceData;
    }

    AppLogger.d('ROOT', '[MAINTENANCE] No maintenance needed');
    return null;
  } catch (e) {
    AppLogger.e('ROOT', '[MAINTENANCE_ERROR] Error checking maintenance: $e');
    return null;
  }
});

/// The original provider, now just processes stats for iOS
final rootCombineProvider = Provider.family<void, BuildContext>(
  (ref, context) {
    if (Platform.isIOS) {
      // Process any pending track completions at startup
      processPendingCompletedTracks().then((processedCount) {
        if (processedCount > 0) {
          debugPrint(
              '[STATS] Processed $processedCount pending tracks on startup');
        }
      });
    }
  },
);
