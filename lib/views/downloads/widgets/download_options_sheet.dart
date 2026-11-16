import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/theme/medito_text.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/downloads/download_settings_provider.dart';
import 'package:medito/views/settings/manage_defaults_screen.dart';

Future<void> showDownloadOptionsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
      builder: (_) => const DownloadOptionsSheet(),
    );

class DownloadOptionsSheet extends ConsumerWidget {
  const DownloadOptionsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(downloadSettingsProvider);
    final notifier = ref.read(downloadSettingsProvider.notifier);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.downloadOptions, style: context.text.title),
            ),
            const SizedBox(height: 20),
            _OptionCard(
              title: l10n.autoDeleteCompletedDownloads,
              description: l10n.autoDeleteCompletedDownloadsDescription,
              value: settings.deleteCompleted,
              onChanged: notifier.setDeleteCompleted,
            ),
            const SizedBox(height: 12),
            _OptionCard(
              title: l10n.autoDownloadNextSession,
              description: l10n.autoDownloadNextSessionDescription(
                l10n.upNext,
                l10n.home,
              ),
              value: settings.downloadNext,
              onChanged: notifier.setDownloadNext,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ManageDefaultsScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: Text(
                      l10n.downloadDefaultVoiceAndLength,
                      style: context.text
                          .on(Theme.of(context).colorScheme.primary)
                          .bodySmall
                          .copyWith(decoration: TextDecoration.underline),
                    ),
                  ),
                  if (settings.downloadNext) ...[
                    const Divider(height: 32),
                    Text(l10n.downloadUsing, style: context.text.label),
                    const SizedBox(height: 8),
                    RadioGroup<bool>(
                      groupValue: settings.useMobileData,
                      onChanged: (value) {
                        if (value != null) notifier.setUseMobileData(value);
                      },
                      child: Column(
                        children: [
                          _NetworkOption(
                            value: false,
                            title: l10n.downloadWifiOnly,
                          ),
                          _NetworkOption(
                            value: true,
                            title: l10n.downloadWifiAndMobileData,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.autoDownloadForegroundNote,
              style: context.text.muted.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    this.child,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MergeSemantics(
              child: InkWell(
                onTap: () => onChanged(!value),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    Expanded(child: Text(title, style: context.text.subtitle)),
                    const SizedBox(width: 12),
                    Switch.adaptive(value: value, onChanged: onChanged),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(description, style: context.text.muted.bodySmall),
            ?child,
          ],
        ),
      ),
    );
  }
}

class _NetworkOption extends StatelessWidget {
  const _NetworkOption({required this.value, required this.title});

  final bool value;
  final String title;

  @override
  Widget build(BuildContext context) => RadioListTile<bool>(
    value: value,
    title: Text(title, style: context.text.bodySmall),
    contentPadding: EdgeInsets.zero,
    dense: true,
    visualDensity: VisualDensity.compact,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );
}
