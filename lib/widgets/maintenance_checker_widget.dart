import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/maintenance/maintenance_model.dart';
import 'package:medito/providers/root/root_combine_provider.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/views/maintenance/maintenance_view.dart';
import '../../../utils/logger.dart';

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
  OverlayEntry? _maintenanceOverlay;

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
        // Show maintenance view if model is not null
        if (maintenanceModel != null) {
          // Use post frame callback to ensure overlay is added after the frame is built
          // This ensures the navigator overlay is ready
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_maintenanceOverlay == null && mounted) {
              _showMaintenanceOverlay(maintenanceModel);
            }
          });
        } else {
          // Remove overlay if maintenance is no longer needed
          if (_maintenanceOverlay != null) {
            _maintenanceOverlay?.remove();
            _maintenanceOverlay = null;
          }
        }

        return widget.child;
      },
      loading: () {
        // Don't show overlay while loading
        if (_maintenanceOverlay != null) {
          _maintenanceOverlay?.remove();
          _maintenanceOverlay = null;
        }
        return widget.child;
      },
      error: (error, stackTrace) {
        AppLogger.e('MAINTENANCE',
            '[MAINTENANCE_ERROR] Error in maintenance checker: $error');
        // Don't show overlay on error
        if (_maintenanceOverlay != null) {
          _maintenanceOverlay?.remove();
          _maintenanceOverlay = null;
        }
        return widget.child;
      },
    );
  }

  void _showMaintenanceOverlay(MaintenanceModel maintenanceModel) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      debugPrint(
          '[MAINTENANCE_ERROR] Navigator is null, cannot show maintenance view');
      return;
    }

    final overlay = navigator.overlay;
    if (overlay == null) {
      debugPrint(
          '[MAINTENANCE_ERROR] Overlay is null, cannot show maintenance view');
      return;
    }

    _maintenanceOverlay = OverlayEntry(
      builder: (context) => PopScope(
        canPop: false, // Prevent back button from dismissing
        child: Material(
          color: Colors.black,
          child: MaintenanceView(
            maintenanceModel: maintenanceModel,
            onClose: () {
              _maintenanceOverlay?.remove();
              _maintenanceOverlay = null;
            },
          ),
        ),
      ),
    );

    overlay.insert(_maintenanceOverlay!);
    debugPrint('[MAINTENANCE] Maintenance overlay inserted');
  }
}
