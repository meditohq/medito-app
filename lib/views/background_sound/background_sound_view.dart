import 'package:medito/providers/providers.dart';
import 'package:medito/models/timer/timer_session.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/models.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/background_sounds/background_sounds_notifier.dart';
import 'widgets/sound_listtile_widget.dart';
import 'widgets/volume_slider_widget.dart';

/// Opens the background-sound picker as a draggable bottom sheet over the
/// player, so the session stays in view instead of being pushed off-screen.
Future<void> showBackgroundSoundSheet(BuildContext context) {
  // A failed fetch is kept (keepAlive); retry it each time the sheet opens so
  // coming back online shows every sound again.
  final container = ProviderScope.containerOf(context);
  if (container.read(backgroundSoundsProvider).hasError) {
    container.invalidate(backgroundSoundsProvider);
  }
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 1,
      builder: (context, scrollController) =>
          BackgroundSoundView(scrollController: scrollController),
    ),
  );
}

/// Background-sound picker: volume bar plus the list of sounds. Shown inside
/// [showBackgroundSoundSheet]; [scrollController] ties the list to the
/// sheet's drag so scrolling past the top expands or dismisses it.
///
/// Renders from [backgroundSoundCatalogProvider]: the live list once it
/// loads, the cached one meanwhile, and offline the sounds that aren't
/// downloaded are greyed out instead of the sheet loading forever.
class BackgroundSoundView extends ConsumerWidget {
  const BackgroundSoundView({super.key, this.scrollController});

  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(backgroundSoundCatalogProvider);
    final Widget? footer;
    if (catalog.loading) {
      footer = const BackgroundSoundsShimmerWidget();
    } else if (catalog.offline && catalog.sounds.isEmpty) {
      footer = MeditoErrorWidget(
        error: const UnknownError(),
        onTap: () => ref.invalidate(backgroundSoundsProvider),
        isScaffold: false,
      );
    } else {
      footer = null;
    }
    return _mainContent(context, ref, catalog, footer: footer);
  }

  Widget _mainContent(
    BuildContext context,
    WidgetRef ref,
    BackgroundSoundCatalog catalog, {
    Widget? footer,
  }) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    // Volume stays pinned above the scrolling list. No pull-to-refresh: in a
    // sheet, pulling down at the top should collapse the sheet, and the error
    // footer already offers a retry.
    return Column(
      children: [
        const VolumeSliderWidget(),
        // Breathing room between the pinned volume bar and the list.
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom + 16,
            ),
            children: [
              // Bells are a switch: they play alongside any sound below.
              const _SessionBellsSwitch(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  AppLocalizations.of(
                    context,
                  )!.backgroundSoundsSection.toUpperCase(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              // None first, so it reads as turning the sound off.
              const SoundListTileWidget(
                sound: BackgroundSoundsModel(
                  id: kNoneBackgroundSoundId,
                  title: 'None',
                  path: '',
                  duration: 0,
                ),
              ),
              ...catalog.sounds.map(
                (e) => SoundListTileWidget(
                  sound: e,
                  available: catalog.isAvailable(e),
                ),
              ),
              ?footer,
            ],
          ),
        ),
      ],
    );
  }
}

class _SessionBellsSwitch extends ConsumerWidget {
  const _SessionBellsSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final l10n = AppLocalizations.of(context)!;
    final enabled = ref.watch(
      backgroundSoundsNotifierProvider.select((s) => s.bellsEnabled),
    );

    void toggle(bool value) {
      FirebaseAnalyticsService().logEvent(
        name: AnalyticsEventConstants.sessionBellsToggled,
        parameters: {
          'enabled': value ? 1 : 0,
          'is_timer': (ref.read(playerProvider)?.isTimer ?? false) ? 1 : 0,
        },
      );
      ref
          .read(backgroundSoundsNotifierProvider.notifier)
          .setSessionBells(value);
    }

    // Same type and margins as the sound rows below.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: InkWell(
        onTap: () => toggle(!enabled),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.sessionBells,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.sessionBellsDescription,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        color: onSurface.withValues(alpha: 0.7),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(value: enabled, onChanged: toggle),
            ],
          ),
        ),
      ),
    );
  }
}
