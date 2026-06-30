import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/maintenance/maintenance_model.dart';
import 'package:medito/providers/root/root_combine_provider.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/views/maintenance/maintenance_view.dart';
import '../../../utils/logger.dart';

/// Widget that watches for maintenance status and shows the maintenance screen when needed
class MaintenanceChecker extends ConsumerStatefulWidget {
  const MaintenanceChecker({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MaintenanceChecker> createState() => _MaintenanceCheckerState();
}

class _MaintenanceCheckerState extends ConsumerState<MaintenanceChecker> {
  OverlayEntry? _maintenanceOverlay;
  MaintenanceModel? _dismissedMaintenanceModel;

  @override
  void dispose() {
    _maintenanceOverlay?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maintenanceState = ref.watch(maintenanceNeededProvider);

    return maintenanceState.when(
      data: (maintenanceModel) {
        if (maintenanceModel == null) {
          _dismissedMaintenanceModel = null;
          if (_maintenanceOverlay != null) {
            _maintenanceOverlay?.remove();
            _maintenanceOverlay = null;
          }
        } else {
          if (_isDifferentMaintenance(maintenanceModel) &&
              _maintenanceOverlay == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_maintenanceOverlay == null && mounted) {
                _showMaintenanceOverlay(maintenanceModel);
              }
            });
          }
        }

        return widget.child;
      },
      loading: () {
        if (_maintenanceOverlay != null) {
          _maintenanceOverlay?.remove();
          _maintenanceOverlay = null;
        }
        return widget.child;
      },
      error: (error, stackTrace) {
        AppLogger.e(
          'MAINTENANCE',
          '[MAINTENANCE_ERROR] Error in maintenance checker: $error',
        );
        if (_maintenanceOverlay != null) {
          _maintenanceOverlay?.remove();
          _maintenanceOverlay = null;
        }
        return widget.child;
      },
    );
  }

  bool _isDifferentMaintenance(MaintenanceModel maintenanceModel) {
    if (_dismissedMaintenanceModel == null) {
      return true;
    }

    final dismissed = _dismissedMaintenanceModel!;
    return dismissed.message != maintenanceModel.message ||
        dismissed.isUnderMaintenance != maintenanceModel.isUnderMaintenance ||
        dismissed.minimumBuildNumber != maintenanceModel.minimumBuildNumber;
  }

  void _showMaintenanceOverlay(MaintenanceModel maintenanceModel) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      AppLogger.e(
        'MAINTENANCE',
        'Navigator is null, cannot show maintenance view',
      );
      return;
    }

    final overlay = navigator.overlay;
    if (overlay == null) {
      AppLogger.e(
        'MAINTENANCE',
        'Overlay is null, cannot show maintenance view',
      );
      return;
    }

    _maintenanceOverlay = OverlayEntry(
      builder: (context) => PopScope(
        canPop: false,
        child: Material(
          color: Colors.black,
          child: MaintenanceView(
            maintenanceModel: maintenanceModel,
            onClose: () {
              _dismissedMaintenanceModel = maintenanceModel;
              _maintenanceOverlay?.remove();
              _maintenanceOverlay = null;
            },
          ),
        ),
      ),
    );

    overlay.insert(_maintenanceOverlay!);
    AppLogger.d('MAINTENANCE', 'Maintenance overlay inserted');
  }
}
