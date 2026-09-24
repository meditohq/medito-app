import 'package:medito/exceptions/app_error.dart';
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
class BackgroundSoundView extends ConsumerWidget {
  const BackgroundSoundView({super.key, this.scrollController});

  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backgroundSounds = ref.watch(backgroundSoundsProvider);

    return backgroundSounds.when(
      skipLoadingOnRefresh: false,
      data: (data) => _mainContent(context, ref, data),
      error: (err, stack) {
        final error = err is AppError ? err : const UnknownError();

        return _mainContent(
          context,
          ref,
          [],
          footer: MeditoErrorWidget(
            error: error,
            onTap: () => ref.refresh(backgroundSoundsProvider),
            isScaffold: false,
          ),
        );
      },
      loading: () => _mainContent(
        context,
        ref,
        [],
        footer: const BackgroundSoundsShimmerWidget(),
      ),
    );
  }

  Widget _mainContent(
    BuildContext context,
    WidgetRef ref,
    List<BackgroundSoundsModel> data, {
    Widget? footer,
  }) {
    // Volume stays pinned above the scrolling list. No pull-to-refresh: in a
    // sheet, pulling down at the top should collapse the sheet, and the error
    // footer already offers a retry.
    return Column(
      children: [
        const VolumeSliderWidget(),
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom + 16,
            ),
            children: [
              const SoundListTileWidget(
                sound: BackgroundSoundsModel(
                  id: kNoneBackgroundSoundId,
                  title: 'None',
                  path: '',
                  duration: 0,
                ),
              ),
              const SoundListTileWidget(sound: kSessionBellsSound),
              ...data
                  .where(
                    (sound) =>
                        sound.id != kNoneBackgroundSoundId &&
                        sound.id != kSessionBellsId,
                  )
                  .map((e) => SoundListTileWidget(sound: e)),
              ?footer,
            ],
          ),
        ),
      ],
    );
  }
}
