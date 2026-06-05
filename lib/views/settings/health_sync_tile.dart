// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/utils/health_kit_manager.dart';

import '../../widgets/snackbar_widget.dart';
import '../../l10n/app_localizations.dart';
import '../home/widgets/bottom_sheet/row_item_widget.dart';
import '../../widgets/medito_icon.dart';

class HealthSyncTile extends StatelessWidget {
  const HealthSyncTile({super.key, this.hasUnderline = true});

  final bool hasUnderline;

  void _handleHealthSync(BuildContext context) async {
    final manager = HealthKitManager();
    final l10n = AppLocalizations.of(context)!;

    if (Platform.isAndroid && !await manager.isHealthConnectAvailable()) {
      await manager.installHealthConnect();
      showSnackBar(context, l10n.healthConnectNotInstalled);
      return;
    }

    await manager.requestAuthorization();

    final explanation = Platform.isAndroid
        ? l10n.permissionExplanationAndroid
        : l10n.permissionExplanation;
    showSnackBar(context, explanation);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title =
        Platform.isAndroid ? l10n.syncWithHealthConnect : l10n.syncWithHealth;
    return RowItemWidget(
      icon: MeditoIcon(
        assetName: MeditoIcons.health,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      title: title,
      hasUnderline: hasUnderline,
      isSwitch: false,
      onTap: () => _handleHealthSync(context),
    );
  }
}
