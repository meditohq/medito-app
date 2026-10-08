import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/services/watch_presence_service.dart';
import 'package:medito/src/watch_presence_pigeon.g.dart';
import 'package:medito/views/home/widgets/bottom_sheet/row_item_widget.dart';
import 'package:medito/widgets/medito_icon.dart';
import 'package:medito/widgets/snackbar_widget.dart';

/// Settings row offering the Medito watch app, shown only while a watch is
/// paired without it (see [watchInstallPromptProvider]). Re-checked on resume
/// so it disappears once the app is installed.
///
/// Android opens Medito's Play Store page on the watch. iOS can't install
/// from the phone, so it shows the Watch app steps in [WatchInstallSheet].
class WatchInstallTile extends ConsumerStatefulWidget {
  const WatchInstallTile({super.key, this.hasUnderline = true});

  final bool hasUnderline;

  @override
  ConsumerState<WatchInstallTile> createState() => _WatchInstallTileState();
}

class _WatchInstallTileState extends ConsumerState<WatchInstallTile> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(watchInstallPromptProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    if (Platform.isIOS) {
      _log('row');
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
        builder: (_) => WatchInstallSheet(
          onOpened: (o) => _log('open_watch_app', opened: o),
        ),
      );
      return;
    }

    final opened = await openWatchInstall();
    _log('row', opened: opened);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    showSnackBar(
      context,
      opened ? l10n.watchInstallAndroidOpened : l10n.watchInstallAndroidFailed,
    );
  }

  void _log(String action, {bool? opened}) {
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: AnalyticsEventConstants.watchInstallPromptTapped,
            parameters: {
              'action': action,
              if (opened != null) 'opened': '$opened',
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(watchInstallPromptProvider).value != true) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;

    return RowItemWidget(
      icon: MeditoIcon(
        assetName: MeditoIcons.smartwatch,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      title: l10n.watchInstallTitle,
      subTitle: l10n.watchInstallSubtitle,
      hasUnderline: widget.hasUnderline,
      onTap: _onTap,
    );
  }
}

/// Opens the watch's store (Android) or the Watch app (iOS); false if nothing
/// could be opened.
Future<bool> openWatchInstall() async {
  try {
    return await WatchPresenceApi().openWatchInstall().timeout(
      const Duration(seconds: 10),
    );
  } catch (_) {
    return false;
  }
}

/// iOS steps for installing the watch app from Apple's Watch app, with a
/// button that opens it.
class WatchInstallSheet extends StatelessWidget {
  const WatchInstallSheet({super.key, required this.onOpened});

  final ValueChanged<bool> onOpened;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final steps = [
      l10n.watchInstallIosStep1,
      l10n.watchInstallIosStep2,
      l10n.watchInstallIosStep3,
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.watchInstallTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                color: onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.watchInstallIosIntro,
              style: theme.textTheme.bodyMedium?.copyWith(color: onSurface),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '${i + 1}.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        steps[i],
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                foregroundColor: context.onBrandAccent,
                backgroundColor: context.brandAccent,
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: () async {
                final opened = await openWatchInstall();
                onOpened(opened);
                if (opened && context.mounted) Navigator.of(context).pop();
              },
              child: Text(l10n.watchInstallOpenWatchApp),
            ),
          ],
        ),
      ),
    );
  }
}
