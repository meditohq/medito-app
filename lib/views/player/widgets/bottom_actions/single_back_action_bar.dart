import 'package:flutter/material.dart';

import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/widgets/medito_icon.dart';

import 'bottom_action_bar.dart';

class SingleBackButtonActionBar extends StatelessWidget {
  const SingleBackButtonActionBar({
    super.key,
    required this.onBackPressed,
    this.showCloseIcon = false,
  });

  final VoidCallback onBackPressed;
  final bool showCloseIcon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BottomActionBar(
      leftItem: BottomActionBarItem(
        child: MeditoIcon(
          assetName: showCloseIcon ? MeditoIcons.xmark : MeditoIcons.arrowLeft,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        onTap: onBackPressed,
        semanticLabel: showCloseIcon ? l10n.close : l10n.goBack,
      ),
    );
  }
}
