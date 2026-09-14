import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/settings/settings_providers.dart';
import 'package:medito/views/home/widgets/bottom_sheet/row_item_widget.dart';
import 'package:medito/widgets/radio_option_card.dart';
import 'package:medito/widgets/snackbar_widget.dart';

/// Settings row for Zen Mode: shows On / Off and opens [ZenModeSheet] on tap.
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
    final enabled = ref.watch(zenModeProvider);
    final l10n = AppLocalizations.of(context)!;

    return RowItemWidget(
      icon: icon,
      title: title,
      subTitle: enabled ? l10n.zenModeOn : l10n.zenModeOff,
      hasUnderline: hasUnderline,
      onTap: () async {
        final wasEnabled = ref.read(zenModeProvider);
        await showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          // Two option cards plus the intro overflow the default 9/16 cap.
          isScrollControlled: true,
          backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
          builder: (_) => const ZenModeSheet(),
        );
        if (!context.mounted) return;
        if (!wasEnabled && ref.read(zenModeProvider)) {
          showSnackBar(context, l10n.zenModeEnabledMessage);
        }
      },
    );
  }
}

/// Bottom sheet explaining Zen Mode with an On and an Off option card.
/// Tapping either applies it and closes the sheet.
class ZenModeSheet extends ConsumerWidget {
  const ZenModeSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final enabled = ref.watch(zenModeProvider);
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    Future<void> choose(bool value) async {
      await ref.read(zenModeProvider.notifier).setEnabled(value);
      if (context.mounted) Navigator.of(context).pop();
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.zenMode,
              style: theme.textTheme.titleMedium?.copyWith(
                color: onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            RadioOptionCard(
              title: l10n.zenModeOn,
              description: l10n.zenModeOnDescription,
              selected: enabled,
              onTap: () => choose(true),
            ),
            const SizedBox(height: 12),
            RadioOptionCard(
              title: l10n.zenModeOff,
              description: l10n.zenModeOffDescription,
              selected: !enabled,
              onTap: () => choose(false),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.zenModeFootnote,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w400,
                color: onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
