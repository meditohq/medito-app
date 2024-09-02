import 'package:Medito/utils/stats_updater.dart';
import 'package:flutter/material.dart';
import 'package:health/health.dart';

import '../../constants/strings/string_constants.dart';
import '../home/widgets/bottom_sheet/row_item_widget.dart';

class HealthSyncTile extends StatelessWidget {
  void _handleHealthSync(BuildContext context) async {
    var types = <HealthDataType>[HealthDataType.MINDFULNESS];

    // Attempt to request authorization for the desired types
    var success = await isHealthSyncPermitted() == true;

    if (success) {
      // If the dialog does not appear, provide guidance to change permissions in the Health app
      showSnackBar(context,
          "Permissions already set. To change them, go to the Settings app > Privacy and Security > Health > Medito.",);
    } else {
      // Handle the case where permissions were not updated
      showSnackBar(context,
          "Failed to open Apple Health permissions. Please check your settings.");
    }
  }

  void showSnackBar(BuildContext context, String message) {
    final snackBar = SnackBar(content: Text(message));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
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
