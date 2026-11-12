import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/background_sounds/session_bell_pattern.dart';
import 'package:medito/providers/timer/timer_bell_settings_provider.dart';
import 'package:medito/widgets/medito_icon.dart';
import 'package:medito/constants/theme/medito_text.dart';

/// A compact summary on setup; the choices live in its bottom sheet.
///
/// The sheet adapts to [isStopwatch]: a stopwatch has no end to ring, so only
/// the Beginning cue is offered, alongside the recurring "every X minutes"
/// chips.
class TimerBellsTile extends ConsumerWidget {
  const TimerBellsTile({super.key, required this.isStopwatch});

  final bool isStopwatch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(timerBellSettingsProvider);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final labels = <String>[
      if (settings.pattern.hasBeginning) l10n.sessionBellBeginning,
      if (!isStopwatch && settings.pattern.hasMiddle) l10n.sessionBellMiddle,
      if (!isStopwatch && settings.pattern.hasEnd) l10n.sessionBellEnd,
      if (settings.intervalSeconds > 0)
        _intervalLabel(l10n, settings.intervalSeconds),
    ];
    final summary = labels.isEmpty ? l10n.none : labels.join(' · ');
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
        titleTextStyle: context.text.body.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
        ),
        subtitle: Text(summary),
        subtitleTextStyle: context.text.bodySmall.copyWith(
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
          builder: (_) => TimerBellsSheet(isStopwatch: isStopwatch),
        ),
      ),
    );
  }
}

class TimerBellsSheet extends ConsumerWidget {
  const TimerBellsSheet({super.key, required this.isStopwatch});

  final bool isStopwatch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(timerBellSettingsProvider);
    // A stopwatch has no length, so Middle and End would never fire; hide
    // them.
    final cues = isStopwatch
        ? const [SessionBellCue.beginning]
        : SessionBellCue.values;
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
                  l10n.sessionBells,
                  style: context.text.label.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final cue in cues)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      visualDensity: VisualDensity.compact,
                      title: Text(switch (cue) {
                        SessionBellCue.beginning => l10n.sessionBellBeginning,
                        SessionBellCue.middle => l10n.sessionBellMiddle,
                        SessionBellCue.end => l10n.sessionBellEnd,
                      }),
                      value: settings.pattern.includes(cue),
                      onChanged: (selected) {
                        if (selected != null) {
                          ref
                              .read(timerBellSettingsProvider.notifier)
                              .setCue(cue, selected);
                        }
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(
                l10n.sessionBellEveryXMinutes,
                style: context.text.label.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: kTimerBellIntervalOptionsSeconds.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final seconds = kTimerBellIntervalOptionsSeconds[i];
                  final selected = seconds == settings.intervalSeconds;
                  return _IntervalChip(
                    label: seconds == 0
                        ? l10n.sessionBellIntervalOff
                        : l10n.sessionBellIntervalMinutes(seconds ~/ 60),
                    selected: selected,
                    onTap: () => ref
                        .read(timerBellSettingsProvider.notifier)
                        .setIntervalSeconds(seconds),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _IntervalChip extends StatelessWidget {
  const _IntervalChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);
    final foreground = selected
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface.withValues(alpha: 0.85);
    return Material(
      color: background,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            label,
            style: context.text.label.copyWith(color: foreground),
          ),
        ),
      ),
    );
  }
}

String _intervalLabel(AppLocalizations l10n, int seconds) =>
    l10n.sessionBellIntervalMinutes(seconds ~/ 60);
