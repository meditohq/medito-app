import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/providers/root/root_combine_provider.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/views/maintenance/maintenance_view.dart';

/// Widget that watches for maintenance status and shows the maintenance screen when needed
class MaintenanceChecker extends ConsumerStatefulWidget {
  const MaintenanceChecker({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<MaintenanceChecker> createState() => _MaintenanceCheckerState();
}

class _MaintenanceCheckerState extends ConsumerState<MaintenanceChecker> {
  bool _hasCheckedMaintenance = false;

  @override
  Widget build(BuildContext context) {
    final maintenanceState = ref.watch(maintenanceNeededProvider);

    return maintenanceState.when(
      data: (maintenanceModel) {
        // Only show maintenance view if model is not null and we haven't already checked
        if (maintenanceModel != null && !_hasCheckedMaintenance) {
          debugPrint(
              '[MAINTENANCE] Maintenance needed, attempting to show maintenance view');

          // Mark that we've checked so we don't try to navigate multiple times
          _hasCheckedMaintenance = true;

          // Delay navigation slightly to ensure app is fully initialized
          Future.delayed(const Duration(milliseconds: 500), () {
            try {
              if (!mounted) {
                debugPrint(
                    '[MAINTENANCE_ERROR] Widget not mounted, cannot navigate');
                return;
              }

              // Use the global navigator key instead of context
              final navigator = navigatorKey.currentState;
              if (navigator != null) {
                debugPrint(
                    '[MAINTENANCE] Showing maintenance view with navigator key');
                navigator.push(
                  MaterialPageRoute(
                    builder: (context) => MaintenanceView(
                      maintenanceModel: maintenanceModel,
                    ),
                  ),
                );
              } else {
                debugPrint(
                    '[MAINTENANCE_ERROR] Navigator is null, cannot show maintenance view');
              }
            } catch (e) {
              debugPrint(
                  '[MAINTENANCE_ERROR] Error showing maintenance view: $e');
            }
          });
        }

        return widget.child;
      },
      loading: () => widget.child,
      error: (error, stackTrace) {
        AppLogger.e('MAINTENANCE', '[MAINTENANCE_ERROR] Error in maintenance checker: $error');
        return widget.child;
      },
    );
  }
}

import '../utils/logger.dart';