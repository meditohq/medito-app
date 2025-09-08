import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/theme_provider.dart';

class ThemeSelectionDialog extends ConsumerWidget {
  const ThemeSelectionDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeProvider);

    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.selectTheme),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildThemeOption(
            context,
            ref,
            ThemeMode.system,
            AppLocalizations.of(context)!.systemTheme,
            HugeIcons.solidRoundedSettings01,
            currentTheme,
          ),
          const SizedBox(height: 8),
          _buildThemeOption(
            context,
            ref,
            ThemeMode.light,
            AppLocalizations.of(context)!.lightTheme,
            HugeIcons.solidRoundedSun01,
            currentTheme,
          ),
          const SizedBox(height: 8),
          _buildThemeOption(
            context,
            ref,
            ThemeMode.dark,
            AppLocalizations.of(context)!.darkTheme,
            HugeIcons.solidRoundedMoon,
            currentTheme,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    WidgetRef ref,
    ThemeMode themeMode,
    String title,
    IconData icon,
    ThemeMode currentTheme,
  ) {
    final isSelected = currentTheme == themeMode;

    return InkWell(
      onTap: () {
        ref.read(themeProvider.notifier).setTheme(themeMode);
        Navigator.of(context).pop();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: icon,
              size: 20,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}
