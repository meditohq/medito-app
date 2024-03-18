import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../constants/strings/route_constants.dart';
import '../maintenance/maintenance_provider.dart';

final rootCombineProvider = Provider.family<void, BuildContext>(
  (ref, context) {
    ref.read(refreshStatsProvider);
    // ref.read(authProvider.notifier).saveFcmTokenEvent();
    ref.read(deviceAppAndUserInfoProvider);

    checkMaintenance(ref, context);
  },
);

void checkMaintenance(ProviderRef<void> ref, BuildContext context) {
  ref.read(fetchMaintenanceProvider.future).then(
    (maintenanceData) {
      ref.read(deviceAndAppInfoProvider.future).then(
        (deviceInfo) {
          var buildNumber = int.parse(deviceInfo.buildNumber);
          if (maintenanceData.isUnderMaintenance ||
              (maintenanceData.minimumBuildNumber ?? 0) > buildNumber) {
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
