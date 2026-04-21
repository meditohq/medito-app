import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/theme_provider.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/widgets/dialogs/dialogs.dart';
import 'package:medito/widgets/medito_icon.dart';

class ThemeSelectionDialog extends ConsumerWidget {
  const ThemeSelectionDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeProvider);
    final l10n = AppLocalizations.of(context)!;

    return MeditoDialog(
      title: l10n.selectTheme,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildThemeOption(
            context,
            ref,
            ThemeMode.system,
            l10n.systemTheme,
            MeditoIcons.settings,
            currentTheme,
          ),
          const SizedBox(height: 8),
          _buildThemeOption(
            context,
            ref,
            ThemeMode.light,
            l10n.lightTheme,
            MeditoIcons.sun,
            currentTheme,
          ),
          const SizedBox(height: 8),
          _buildThemeOption(
            context,
            ref,
            ThemeMode.dark,
            l10n.darkTheme,
            MeditoIcons.moon,
            currentTheme,
          ),
        ],
      ),
      actions: [
        MeditoDialogSecondaryButton(
          label: l10n.cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    WidgetRef ref,
    ThemeMode themeMode,
    String title,
    String iconAsset,
    ThemeMode currentTheme,
  ) {
    final theme = Theme.of(context);
    final isSelected = currentTheme == themeMode;

    return InkWell(
      onTap: () {
        ref.read(themeProvider.notifier).setTheme(themeMode);
        Navigator.of(context).pop();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? theme.colorScheme.primary.withOpacityValue(0.1)
              : theme.cardColor,
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary.withOpacityValue(0.4)
                : theme.colorScheme.outline.withOpacityValue(0.3),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            MeditoIcon(
              assetName: iconAsset,
              size: 20,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check,
                size: 20,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}
