// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../widgets/snackbar_widget.dart';
import '../../l10n/app_localizations.dart';
import '../home/widgets/bottom_sheet/row_item_widget.dart';

class HealthSyncTile extends StatelessWidget {
  const HealthSyncTile({super.key});

  void _handleHealthSync(BuildContext context) async {
    await Health().requestAuthorization(
      [HealthDataType.MINDFULNESS],
      permissions: [HealthDataAccess.READ_WRITE],
    );

    showSnackBar(context, AppLocalizations.of(context)!.permissionExplanation);
  }

  @override
  Widget build(BuildContext context) {
    return RowItemWidget(
      icon: HugeIcon(
        icon: HugeIcons.solidRoundedHealth,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      title: AppLocalizations.of(context)!.syncWithHealth,
      hasUnderline: true,
      isSwitch: false,
      onTap: () => _handleHealthSync(context),
    );
  }
}
