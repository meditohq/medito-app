import 'package:flutter/material.dart';
import 'package:health/health.dart';

import '../../constants/strings/string_constants.dart';
import '../../widgets/snackbar_widget.dart';
import '../home/widgets/bottom_sheet/row_item_widget.dart';

class HealthSyncTile extends StatelessWidget {
  const HealthSyncTile({super.key});

  void _handleHealthSync(BuildContext context) async {
    await Health().requestAuthorization(
      [HealthDataType.MINDFULNESS],
      permissions: [HealthDataAccess.READ_WRITE],
    );

    showSnackBar(
      context,
      StringConstants.permissionExplanation,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RowItemWidget(
      enableInteractiveSelection: false,
      icon: IconType.fromIconData(Icons.sync),
      title: StringConstants.syncWithHealth,
      hasUnderline: true,
      isSwitch: false,
      onTap: () => _handleHealthSync(context),
    );
  }
}
