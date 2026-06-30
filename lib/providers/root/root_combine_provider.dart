// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/maintenance/maintenance_model.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/utils/stats_updater.dart';
import '../maintenance/maintenance_provider.dart';

/// Provides the maintenance model if maintenance is needed, null otherwise
final maintenanceNeededProvider = FutureProvider<MaintenanceModel?>((
  ref,
) async {
  try {
    final maintenanceData = await ref.read(fetchMaintenanceProvider.future);

    final deviceInfo = await ref.read(deviceAndAppInfoProvider.future);

    final buildNumber = int.tryParse(deviceInfo.buildNumber) ?? 0;
    final minRequired = maintenanceData.minimumBuildNumber ?? 0;

    final needsMaintenance =
        (maintenanceData.isUnderMaintenance) || minRequired > buildNumber;

    if (needsMaintenance) {
      return maintenanceData;
    }

    return null;
  } catch (e) {
    return null;
  }
});

/// The original provider, now just processes stats for iOS
final rootCombineProvider = Provider.family<void, BuildContext>((ref, context) {
  if (Platform.isIOS) {
    // Process any pending track completions at startup
    processPendingCompletedTracks().then((processedCount) {
      if (processedCount > 0) {
        AppLogger.d(
          'STATS',
          'Processed $processedCount pending tracks on startup',
        );
      }
    });
  }
});
