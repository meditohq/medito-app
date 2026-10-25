import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/background_sounds/session_bell_pattern.dart';
import 'package:medito/providers/timer/timer_bell_settings_provider.dart';
import 'package:medito/views/background_sound/widgets/session_bell_checkboxes.dart';
import 'package:medito/widgets/medito_icon.dart';

/// A compact summary on setup; the three choices live in its bottom sheet.
class TimerBellsTile extends ConsumerWidget {
  const TimerBellsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pattern = ref.watch(timerBellSettingsProvider);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final labels = [
      if (pattern.hasBeginning) l10n.sessionBellBeginning,
      if (pattern.hasMiddle) l10n.sessionBellMiddle,
      if (pattern.hasEnd) l10n.sessionBellEnd,
    ];
    final summary = switch (pattern) {
      SessionBellPattern.none => l10n.none,
      SessionBellPattern.beginningEnd => l10n.sessionBellBeginningEnd,
      SessionBellPattern.beginningMiddleEnd =>
        l10n.sessionBellBeginningMiddleEnd,
      _ => labels.join(' · '),
    };
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minLeadingWidth: 20,
        horizontalTitleGap: 20,
        leading: MeditoIcon(
          assetName: MeditoIcons.bell,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          size: 20,
        ),
        title: Text(l10n.sessionBells),
        titleTextStyle: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w400,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
        ),
        subtitle: Text(summary),
        subtitleTextStyle: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w400,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          size: 20,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: theme.bottomSheetTheme.backgroundColor,
          builder: (_) => const TimerBellsSheet(),
        ),
      ),
    );
  }
}

class TimerBellsSheet extends ConsumerWidget {
  const TimerBellsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Semantics(
                header: true,
                child: Text(
                  AppLocalizations.of(context)!.sessionBells,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            SessionBellCheckboxes(
              pattern: ref.watch(timerBellSettingsProvider),
              onChanged: ref.read(timerBellSettingsProvider.notifier).setCue,
            ),
          ],
        ),
      ),
    );
  }
}
