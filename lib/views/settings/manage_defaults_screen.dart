import 'package:medito/widgets/adaptive/adaptive_page_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/duration_preference_provider.dart';
import 'package:medito/providers/guide_name_preference_provider.dart';
import 'package:medito/views/home/widgets/header/home_header_widget.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';
import 'package:medito/models/track/track.dart';
import 'package:medito/providers/home/up_next_provider.dart';
import 'package:medito/providers/meditation/track_provider.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/widgets/inputs/option_pills.dart';
import 'package:medito/widgets/snackbar_widget.dart' show showSnackBar;

class ManageDefaultsScreen extends ConsumerWidget {
  const ManageDefaultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      bottomNavigationBar: SingleBackButtonActionBar(
        onBackPressed: () => Navigator.pop(context),
      ),
      body: AdaptivePageBody(
        maxWidth: 760,
        child: SafeArea(child: _buildMain(context, ref)),
      ),
    );
  }

  Widget _buildMain(BuildContext context, WidgetRef ref) {
    final guideName = ref.watch(guideNamePreferenceProvider);
    final duration = ref.watch(durationPreferenceProvider);
    final l10n = AppLocalizations.of(context)!;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverAppBar(
          centerTitle: false,
          automaticallyImplyLeading: false,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          toolbarHeight: 56.0,
          pinned: true,
          floating: true,
          elevation: 0.0,
          title: HomeHeaderWidget(greeting: l10n.manageDefaults),
        ),
        _buildContent(context, ref, guideName, duration, l10n),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    String? guideName,
    int? duration,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final guides = _guideOptions(ref, guideName);
    final savedMinutes = duration == null
        ? null
        : convertDurationToMinutes(milliseconds: duration);
    // A saved length off the presets (e.g. an 8-minute track) gets its own
    // pill rather than lighting up the nearest preset.
    final minutes = {..._presetMinutes, ?savedMinutes}.toList()..sort();

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          Text(
            l10n.defaultsNote,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 15,
              color: onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          OptionPillGroup(
            label: l10n.variantVoice,
            options: [
              for (final guide in guides)
                PillOption(
                  text: guide,
                  selected: guide == guideName,
                  onTap: () => ref
                      .read(guideNamePreferenceProvider.notifier)
                      .setGuideName(guide),
                ),
            ],
          ),
          // No Up Next and nothing saved: nothing to offer yet.
          if (guides.isEmpty)
            Text(
              l10n.notSet,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 15,
                color: onSurface.withValues(alpha: 0.7),
              ),
            ),
          const SizedBox(height: 24),
          OptionPillGroup(
            label: l10n.variantLength,
            options: [
              for (final m in minutes)
                PillOption(
                  text: l10n.upNextVariantMinutes(m),
                  selected: m == savedMinutes,
                  onTap: () => ref
                      .read(durationPreferenceProvider.notifier)
                      .setDuration(m * 60000),
                ),
            ],
          ),
          if (guideName != null || duration != null) ...[
            const SizedBox(height: 32),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: onSurface,
                  padding: EdgeInsets.zero,
                ),
                onPressed: () {
                  ref
                      .read(guideNamePreferenceProvider.notifier)
                      .clearGuideName();
                  ref.read(durationPreferenceProvider.notifier).clearDuration();
                  showSnackBar(context, l10n.defaultsCleared);
                },
                child: Text(
                  l10n.clearDefaults,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  /// Lengths most sessions come in; each track plays its closest.
  static const _presetMinutes = [3, 5, 10, 15, 20, 30, 60];

  /// There is no catalogue of guides, so offer the voices of the Up Next
  /// session (Getting started has the main four) plus the saved one.
  List<String> _guideOptions(WidgetRef ref, String? saved) {
    final nextId = ref.watch(upNextProvider).value?.nextSession?.id;
    final track = nextId == null
        ? null
        : ref.watch(tracksProvider(trackId: nextId)).value;
    final guides = <String>[
      for (final voice in track?.voices ?? const <TrackVoice>[])
        if (voice.guideName != null && voice.guideName!.isNotEmpty)
          voice.guideName!,
    ];
    if (saved != null && !guides.contains(saved)) guides.add(saved);
    return guides;
  }
}
