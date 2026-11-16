import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/theme/medito_text.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/downloads/download_settings_provider.dart';
import 'package:medito/providers/duration_preference_provider.dart';
import 'package:medito/providers/guide_name_preference_provider.dart';
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
    final guide = ref.watch(guideNamePreferenceProvider);
    final duration = ref.watch(durationPreferenceProvider);
    final defaults = [
      ?guide,
      if (duration != null)
        l10n.upNextVariantMinutes((duration / 60000).round()),
    ];

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.downloadOptions, style: context.text.title),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.autoDownloadNextSession,
                style: context.text.subtitle,
              ),
              subtitle: Text(
                l10n.autoDownloadNextSessionDescription(l10n.home),
                style: context.text.muted.bodySmall,
              ),
              value: settings.downloadNext,
              onChanged: notifier.setDownloadNext,
            ),
            if (settings.downloadNext) ...[
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n.downloadUseMobileData,
                  style: context.text.body,
                ),
                subtitle: Text(
                  l10n.downloadUseMobileDataDescription,
                  style: context.text.muted.bodySmall,
                ),
                value: settings.useMobileData,
                onChanged: notifier.setUseMobileData,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n.downloadDefaultVoiceAndLength,
                  style: context.text.body,
                ),
                subtitle: defaults.isEmpty
                    ? null
                    : Text(
                        defaults.join(' · '),
                        style: context.text.muted.bodySmall,
                      ),
                trailing: Text(
                  l10n.downloadChangeDefaults,
                  style: context.text.label,
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ManageDefaultsScreen(),
                  ),
                ),
              ),
            ],
            Divider(
              height: 24,
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.1),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.autoDeleteCompletedDownloads,
                style: context.text.subtitle,
              ),
              subtitle: Text(
                l10n.autoDeleteCompletedDownloadsDescription,
                style: context.text.muted.bodySmall,
              ),
              value: settings.deleteCompleted,
              onChanged: notifier.setDeleteCompleted,
            ),
          ],
        ),
      ),
    );
  }
}
