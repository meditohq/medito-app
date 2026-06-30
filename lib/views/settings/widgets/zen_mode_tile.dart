import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/settings/settings_providers.dart';
import 'package:medito/views/home/widgets/bottom_sheet/row_item_widget.dart';
import 'package:medito/widgets/snackbar_widget.dart';

class ZenModeTile extends ConsumerWidget {
  final Widget icon;
  final String title;
  final bool hasUnderline;

  const ZenModeTile({
    super.key,
    required this.icon,
    required this.title,
    this.hasUnderline = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isZenModeEnabled = ref.watch(zenModeProvider);

    return RowItemWidget(
      icon: icon,
      title: title,
      subTitle: AppLocalizations.of(context)!.zenModeSubtitle,
      hasUnderline: hasUnderline,
      isSwitch: true,
      switchValue: isZenModeEnabled,
      onSwitchChanged: (value) {
        ref.read(zenModeProvider.notifier).setEnabled(value);
        if (value) {
          showSnackBar(
            context,
            AppLocalizations.of(context)!.zenModeEnabledMessage,
          );
        }
      },
    );
  }
}
