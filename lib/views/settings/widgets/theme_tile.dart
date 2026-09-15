import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/theme_provider.dart';
import 'package:medito/views/home/widgets/bottom_sheet/row_item_widget.dart';
import 'package:medito/widgets/medito_icon.dart';
import 'package:medito/widgets/radio_option_card.dart';

/// Settings row for the app theme: shows the current choice as subtitle and
/// opens [ThemeSheet] on tap.
class ThemeTile extends ConsumerWidget {
  const ThemeTile({
    super.key,
    required this.icon,
    required this.title,
    this.hasUnderline = true,
  });

  final Widget icon;
  final String title;
  final bool hasUnderline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeProvider);
    final l10n = AppLocalizations.of(context)!;

    return RowItemWidget(
      icon: icon,
      title: title,
      subTitle: switch (mode) {
        ThemeMode.system => l10n.systemTheme,
        ThemeMode.light => l10n.lightTheme,
        ThemeMode.dark => l10n.darkTheme,
      },
      hasUnderline: hasUnderline,
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
        builder: (_) => const ThemeSheet(),
      ),
    );
  }
}

/// Bottom sheet listing System / Light / Dark as radio option cards.
/// Selecting one applies it and closes the sheet.
class ThemeSheet extends ConsumerWidget {
  const ThemeSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final current = ref.watch(themeProvider);
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    final options = <(ThemeMode, String, String?, String)>[
      (
        ThemeMode.system,
        l10n.systemTheme,
        l10n.systemThemeDescription,
        MeditoIcons.settings,
      ),
      (ThemeMode.light, l10n.lightTheme, null, MeditoIcons.sun),
      (ThemeMode.dark, l10n.darkTheme, null, MeditoIcons.moon),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.selectTheme,
              style: theme.textTheme.titleMedium?.copyWith(
                color: onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            for (final (i, (mode, label, description, asset))
                in options.indexed) ...[
              if (i > 0) const SizedBox(height: 12),
              RadioOptionCard(
                title: label,
                description: description,
                selected: mode == current,
                trailing: MeditoIcon(
                  assetName: asset,
                  color: onSurface.withValues(alpha: 0.7),
                  size: 22,
                ),
                onTap: () {
                  ref.read(themeProvider.notifier).setTheme(mode);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
