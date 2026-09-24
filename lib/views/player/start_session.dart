import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/types/type_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/duration_preference_provider.dart';
import 'package:medito/providers/guide_name_preference_provider.dart';
import 'package:medito/providers/meditation/track_provider.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/utils/track_variant_selector.dart';
import 'package:medito/views/player/player_view.dart';

/// Gets the user into [trackId] as fast as possible: straight into the player
/// with their preferred guide and duration when both are known, otherwise via
/// the track screen so they can pick. Shared by Up Next and the pack screen's
/// Your Path button so both start sessions the same way.
Future<void> startSession(
  BuildContext context,
  WidgetRef ref, {
  required String trackId,
  required String path,
}) async {
  final guideName = ref.read(guideNamePreferenceProvider);
  final preferredDuration = ref.read(durationPreferenceProvider);

  if (guideName == null || preferredDuration == null) {
    handleNavigation(TypeConstants.track, [trackId, path], context, ref: ref);
    return;
  }

  try {
    final track = await ref.read(tracksProvider(trackId: trackId).future);
    final selection = TrackVariantSelector.resolve(
      track,
      guideName: guideName,
      durationMs: preferredDuration,
    );
    final request = PlaybackRequest.fromTrack(
      track,
      selection.voice,
      selection.file,
    );
    if (!context.mounted) return;
    // Prepare + open the player immediately; PlayerView starts playback and
    // shows its own loading state. Callers' spinners cover only the fetch.
    ref.read(playerProvider.notifier).prepare(request);
    unawaited(
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PlayerView()),
      ),
    );
  } catch (e, st) {
    // The track fetch failed (offline / bad response) so we never reached
    // the player — surface it rather than leaving a dead tap.
    AppLogger.e('START_SESSION', 'Failed to start session $trackId', e, st);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.unableToLoadAudio)),
    );
  }
}
