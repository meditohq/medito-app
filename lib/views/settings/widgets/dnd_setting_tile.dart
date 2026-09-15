import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/views/home/widgets/bottom_sheet/row_item_widget.dart';
import 'package:medito/widgets/dialogs/dialogs.dart';
import 'package:medito/widgets/radio_option_card.dart';

/// Settings row for "Silence phone during meditation": shows On / Off and
/// opens [DndSheet] on tap. Same shape as the Zen Mode row.
class DndSettingTile extends ConsumerWidget {
  final Widget icon;
  final String title;
  final bool hasUnderline;

  const DndSettingTile({
    super.key,
    required this.icon,
    required this.title,
    this.hasUnderline = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(dndProvider);
    final l10n = AppLocalizations.of(context)!;

    return RowItemWidget(
      icon: icon,
      title: title,
      subTitle: enabled ? l10n.dndOn : l10n.dndOff,
      hasUnderline: hasUnderline,
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
        builder: (_) => DndSheet(title: title),
      ),
    );
  }
}

/// Bottom sheet with an On and an Off option card. Turning it on needs
/// Android's Do Not Disturb access; if that is missing the sheet explains why
/// and offers the system page, then finishes the job when the user comes back
/// with access granted instead of making them tap On a second time.
class DndSheet extends ConsumerStatefulWidget {
  const DndSheet({super.key, required this.title});

  final String title;

  @override
  ConsumerState<DndSheet> createState() => _DndSheetState();
}

class _DndSheetState extends ConsumerState<DndSheet> {
  bool _busy = false;

  Future<void> _choose(bool value) async {
    if (_busy) return;
    final notifier = ref.read(dndProvider.notifier);

    if (value && !await notifier.hasAccess()) {
      setState(() => _busy = true);
      final granted = await _recoverAccess();
      if (!mounted) return;
      setState(() => _busy = false);
      if (!granted) return;
    }

    if (ref.read(dndProvider) != value) {
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .logEvent(
              name: AnalyticsEventConstants.dndSettingChanged,
              parameters: {
                AnalyticsEventConstants.paramEnabled: value.toString(),
                AnalyticsEventConstants.paramSource:
                    AnalyticsEventConstants.sourceSettings,
              },
            ),
      );
    }
    await notifier.setEnabled(value);
    if (mounted) Navigator.of(context).pop();
  }

  /// Explain the permission, offer the system page, and report whether access
  /// is granted once the user is back.
  Future<bool> _recoverAccess() async {
    final analytics = ref.read(analyticsServiceProvider);
    const params = {
      AnalyticsEventConstants.paramSource:
          AnalyticsEventConstants.sourceSettings,
    };

    unawaited(
      analytics.logEvent(
        name: AnalyticsEventConstants.dndAccessPromptShown,
        parameters: params,
      ),
    );

    final go = await _showAccessDialog();
    if (!go || !mounted) return false;

    unawaited(
      analytics.logEvent(
        name: AnalyticsEventConstants.dndAccessSettingsOpened,
        parameters: params,
      ),
    );

    final granted = await ref
        .read(dndProvider.notifier)
        .requestAccessViaSettings();

    unawaited(
      analytics.logEvent(
        name: granted
            ? AnalyticsEventConstants.dndAccessGranted
            : AnalyticsEventConstants.dndAccessDenied,
        parameters: params,
      ),
    );
    return granted;
  }

  Future<bool> _showAccessDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => MeditoDialog(
        title: l10n.dndAccessTitle,
        content: MeditoDialogBody(l10n.dndAccessBody),
        actions: [
          MeditoDialogSecondaryButton(
            label: l10n.notNow,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          MeditoDialogPrimaryButton(
            label: l10n.openSettings,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    return proceed == true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final enabled = ref.watch(dndProvider);
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            RadioOptionCard(
              title: l10n.dndOn,
              description: l10n.dndOnDescription,
              selected: enabled,
              onTap: () => _choose(true),
            ),
            const SizedBox(height: 12),
            RadioOptionCard(
              title: l10n.dndOff,
              description: l10n.dndOffDescription,
              selected: !enabled,
              onTap: () => _choose(false),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.dndFootnote,
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
