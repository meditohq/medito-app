import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/track/track.dart';
import 'package:medito/providers/duration_preference_provider.dart';
import 'package:medito/providers/guide_name_preference_provider.dart';
import 'package:medito/utils/track_variant_selector.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/widgets/inputs/option_pills.dart';

/// Whether [track] offers any choice of voice or length worth showing.
bool trackHasVariants(Track track) =>
    _namedVoices(track).length > 1 ||
    track.voices.any((v) => v.audioFiles.length > 1);

List<TrackVoice> _namedVoices(Track track) => track.voices
    .where((v) => v.guideName != null && v.guideName!.isNotEmpty)
    .toList();

Future<void> showVariantSheet(BuildContext context, Track track) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
    builder: (_) => VariantSheet(track: track),
  );
}

/// Voice and length pickers for [track], opened from the Home hero. A pick
/// saves the default (the same one the track screen's dropdowns set), so the
/// hero line and the next Up Next tap follow it.
class VariantSheet extends ConsumerWidget {
  const VariantSheet({super.key, required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final selection = TrackVariantSelector.resolve(
      track,
      guideName: ref.watch(guideNamePreferenceProvider),
      durationMs: ref.watch(durationPreferenceProvider),
    );
    final voices = _namedVoices(track);
    final files = selection.voice.audioFiles;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.variantSheetTitle,
              // Explicit sizes: the theme's titleMedium (14) is smaller than
              // its bodyMedium (16), which put the title under the note.
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 20,
                color: onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.variantSheetNote,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 15,
                color: onSurface.withValues(alpha: 0.7),
              ),
            ),
            if (voices.length > 1) ...[
              const SizedBox(height: 24),
              OptionPillGroup(
                label: l10n.variantVoice,
                options: [
                  for (final voice in voices)
                    PillOption(
                      text: voice.guideName!,
                      selected: voice == selection.voice,
                      onTap: () => ref
                          .read(guideNamePreferenceProvider.notifier)
                          .setGuideName(voice.guideName),
                    ),
                ],
              ),
            ],
            // Shown even with one length so the sheet always says how long
            // the session is.
            if (files.isNotEmpty) ...[
              const SizedBox(height: 24),
              OptionPillGroup(
                label: l10n.variantLength,
                options: [
                  for (final file in files)
                    PillOption(
                      text: l10n.upNextVariantMinutes(
                        convertDurationToMinutes(milliseconds: file.duration),
                      ),
                      selected: file == selection.file,
                      onTap: () => ref
                          .read(durationPreferenceProvider.notifier)
                          .setDuration(file.duration),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
