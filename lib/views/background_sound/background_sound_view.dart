import 'package:medito/exceptions/app_error.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/models.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/background_sounds/background_sounds_notifier.dart';
import 'widgets/sound_listtile_widget.dart';
import 'widgets/session_bell_checkboxes.dart';
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
              _SoundSectionHeading(
                label: AppLocalizations.of(context)!.sessionBells,
              ),
              SessionBellCheckboxes(
                pattern: ref
                    .watch(backgroundSoundsNotifierProvider)
                    .selectedBellPattern,
                onChanged: ref
                    .read(backgroundSoundsNotifierProvider.notifier)
                    .setSessionBellCue,
              ),
              _SoundSectionHeading(
                label: AppLocalizations.of(context)!.backgroundSoundsSection,
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

class _SoundSectionHeading extends StatelessWidget {
  const _SoundSectionHeading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Semantics(
        header: true,
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
