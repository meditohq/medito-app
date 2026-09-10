import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/settings/settings_providers.dart';
import 'package:medito/views/home/widgets/bottom_sheet/row_item_widget.dart';
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

/// Bottom sheet explaining Zen Mode with an On and an Off button. The current
/// state is the filled button; tapping either applies it and closes the sheet.
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

    Widget button(bool value, String label) {
      final selected = enabled == value;
      return Expanded(
        // ElevatedButton and OutlinedButton share the app theme's 8px shape;
        // FilledButton is unthemed and would render as a pill.
        child: selected
            ? ElevatedButton(onPressed: () => choose(value), child: Text(label))
            : OutlinedButton(
                onPressed: () => choose(value),
                child: Text(label),
              ),
      );
    }

    return SafeArea(
      child: Padding(
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
            const SizedBox(height: 8),
            Text(
              l10n.zenModeDescription,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: onSurface.withValues(alpha: 0.8),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                button(true, l10n.zenModeOn),
                const SizedBox(width: 12),
                button(false, l10n.zenModeOff),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
