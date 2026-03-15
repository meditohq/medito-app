import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/theme_provider.dart';
import 'package:medito/widgets/medito_huge_icon.dart';

class ThemeInlineSelector extends ConsumerWidget {
  const ThemeInlineSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeProvider);
    final l10n = AppLocalizations.of(context)!;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                MeditoIcon(
                  assetName: AssetConstants.icSparks,
                  size: 24,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                width16,
                Text(
                  l10n.themeTitle,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _ThemeButton(
                  label: l10n.darkTheme,
                  iconAsset: MeditoIcons.moon,
                  isSelected: currentTheme == ThemeMode.dark,
                  onTap: () =>
                      ref.read(themeProvider.notifier).setTheme(ThemeMode.dark),
                ),
                const SizedBox(width: 8),
                _ThemeButton(
                  label: l10n.lightTheme,
                  iconAsset: MeditoIcons.sun,
                  isSelected: currentTheme == ThemeMode.light,
                  onTap: () => ref
                      .read(themeProvider.notifier)
                      .setTheme(ThemeMode.light),
                ),
                const SizedBox(width: 8),
                _ThemeButton(
                  label: l10n.systemTheme,
                  iconAsset: MeditoIcons.settings,
                  isSelected: currentTheme == ThemeMode.system,
                  onTap: () => ref
                      .read(themeProvider.notifier)
                      .setTheme(ThemeMode.system),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeButton extends StatelessWidget {
  const _ThemeButton({
    required this.label,
    required this.iconAsset,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String iconAsset;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface;

    return Expanded(
      child: Semantics(
        label: label,
        button: true,
        selected: isSelected,
        child: GestureDetector(
        onTap: onTap,
        child: ExcludeSemantics(
          child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.06),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MeditoIcon(
                assetName: iconAsset,
                size: 20,
                color: color,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
              ),
              ],
          ),
        ),
      ),
      ),
      ),
    );
  }
}
