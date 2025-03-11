import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/utils/stats_updater.dart';
import '../../views/maintenance/maintenance_view.dart';
import '../maintenance/maintenance_provider.dart';

final rootCombineProvider = Provider.family<void, BuildContext>(
  (ref, context) {
    _checkMaintenance(ref, context);

    if (Platform.isIOS) {
      // Process any pending track completions at startup
      processPendingCompletedTracks().then((processedCount) {
        if (processedCount > 0) {
          debugPrint('Processed $processedCount pending tracks on startup');
        }
      });
    }
  },
);

void _checkMaintenance(Ref<void> ref, BuildContext context) async {
  try {
    final maintenanceData = await ref.read(fetchMaintenanceProvider.future);
    final deviceInfo = await ref.read(deviceAndAppInfoProvider.future);

    final buildNumber = int.parse(deviceInfo.buildNumber);
    final minRequired = maintenanceData.minimumBuildNumber ?? 0;

    final needsMaintenance =
        maintenanceData.isUnderMaintenance || minRequired > buildNumber;

    if (needsMaintenance) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MaintenanceView(
            maintenanceModel: maintenanceData,
          ),
        ),
      );
    }
  } catch (e) {
    debugPrint('Error checking maintenance: $e');
  }
}
